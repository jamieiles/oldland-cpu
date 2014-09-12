/*
 * Debug stub for verilog simulation.  This connects a UNIX domain socket to
 * the simulation allowing a debugger to control the simulation.  The stub <->
 * simulation protocol is represented with two system tasks.
 *
 * $dbg_get(req, read_not_write, address, val)
 * $dbg_put(value)
 *
 * If req is set then the stub is requesting a read/write to the debug
 * controller, otherwise no action.
 *
 * $dbg_put() is only called after a completed read request.
 *
 * We have one thread that manages the connection - it performs accept() to
 * get the connection then performs a blocking poll() on the socket to wait
 * for new requests, setting a pending bit so that the model can consume the
 * requests without a syscall in each simulation cycle.
 *
 * The pending bit is set as an atomic from the polling thread (epoll,
 * non-blocking, edge triggered) and cleared from the simulation thread as an
 * atomic_set() after consuming all data on the socket.
 */
#define _GNU_SOURCE

#include <err.h>
#include <errno.h>
#include <fcntl.h>
#include <netdb.h>
#include <pthread.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

#include <sys/epoll.h>
#include <sys/uio.h>
#include <sys/socket.h>
#include <sys/types.h>

#include <vpi_user.h>

#include "../debugger/protocol.h"
#include "../devicemodels/jtag.h"

#define ARRAY_SIZE(x) (sizeof((x)) / sizeof((x)[0]))

enum {
	D_REQ,
	D_RNW,
	D_ADDR,
	D_VALUE,
	D_ARR_SZ,
};

static int dbg_get_calltf(char *user_data)
{
	vpiHandle systfref, args_iter;
	int i, data[D_ARR_SZ];
	struct t_vpi_value argval = {
		.format = vpiIntVal,
	};
	struct jtag_debug_data *jtag_debug_data = (struct jtag_debug_data *)user_data;
	struct dbg_request req;
	struct dbg_response resp;

	systfref = vpi_handle(vpiSysTfCall, NULL);
	args_iter = vpi_iterate(vpiArgument, systfref);

	if (!jtag_debug_data->more_data)
		if(__sync_val_compare_and_swap(&jtag_debug_data->pending, 1, 0) == 0)
			jtag_debug_data->more_data = 1;

	data[D_REQ] = get_request(jtag_debug_data, &req) == 0;
	data[D_RNW] = req.read_not_write;
	data[D_ADDR] = req.addr;
	data[D_VALUE] = req.value;

	for (i = 0; i < D_ARR_SZ; ++i) {
		vpiHandle argh = vpi_scan(args_iter);
		argval.value.integer = data[i];
		vpi_put_value(argh, &argval, NULL, vpiNoDelay);
	}

	if (data[D_REQ] && !data[D_RNW]) {
		resp.status = 0;
		send_response(jtag_debug_data, &resp);
	}

	vpi_free_object(args_iter);

	return 0;
}

static int dbg_put_calltf(char *user_data)
{
	vpiHandle systfref, args_iter;
	struct t_vpi_value argval = {
		.format = vpiIntVal,
	};
	struct jtag_debug_data *jtag_debug_data = (struct jtag_debug_data *)user_data;
	struct dbg_response resp;

	systfref = vpi_handle(vpiSysTfCall, NULL);
	args_iter = vpi_iterate(vpiArgument, systfref);

	vpiHandle argh = vpi_scan(args_iter);
	vpi_get_value(argh, &argval);

	resp.status = 0;
	resp.data = argval.value.integer;
	send_response(jtag_debug_data, &resp);

	vpi_free_object(args_iter);

	return 0;
}

static int dbg_sim_term_calltf(char *user_data)
{
	vpiHandle systfref, args_iter;
	struct t_vpi_value argval = {
		.format = vpiIntVal,
	};
	struct jtag_debug_data *jtag_debug_data = (struct jtag_debug_data *)user_data;
	struct dbg_response resp;

	systfref = vpi_handle(vpiSysTfCall, NULL);
	args_iter = vpi_iterate(vpiArgument, systfref);

	vpiHandle argh = vpi_scan(args_iter);
	vpi_get_value(argh, &argval);

	resp.status = 0;
	resp.data = argval.value.integer;
	send_response(jtag_debug_data, &resp);

	vpi_free_object(args_iter);

	shutdown(jtag_debug_data->client_fd, SHUT_RDWR);
	close(jtag_debug_data->client_fd);
	close(jtag_debug_data->sock_fd);
	jtag_debug_data->client_fd = jtag_debug_data->sock_fd = -1;

	return 0;
}

static void debug_stub_register(void)
{
	struct jtag_debug_data *data;
	s_vpi_systf_data tasks[] = {
		{
			.type		= vpiSysTask,
			.tfname		= "$dbg_get",
			.calltf		= dbg_get_calltf,
			.sizetf		= 0,
		},
		{
			.type		= vpiSysTask,
			.tfname		= "$dbg_put",
			.calltf		= dbg_put_calltf,
			.sizetf		= 0,
		},
		{
			.type		= vpiSysTask,
			.tfname		= "$dbg_sim_term",
			.calltf		= dbg_sim_term_calltf,
			.sizetf		= 0,
		},
	};
	int i;

	data = start_server();

	notify_runner();

	for (i = 0; i < ARRAY_SIZE(tasks); ++i) {
		tasks[i].user_data = (char *)data;
		vpi_register_systf(&tasks[i]);
	}
}

void (*vlog_startup_routines[])(void) = {
	debug_stub_register,
	NULL
};
