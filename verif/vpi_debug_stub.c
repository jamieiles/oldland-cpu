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

struct debug_data {
	int sock_fd;
	int epoll_fd;
	int client_fd;
	int pending;
	int more_data;
	pthread_mutex_t lock;
};

#define ARRAY_SIZE(x) (sizeof((x)) / sizeof((x)[0]))

enum {
	D_REQ,
	D_RNW,
	D_ADDR,
	D_VALUE,
	D_ARR_SZ,
};

static int get_request(struct debug_data *d, struct dbg_request *req)
{
	ssize_t br;
	int rc = -EAGAIN;

	pthread_mutex_lock(&d->lock);

	if (d->client_fd < 0)
		goto out;

	if (!d->more_data)
		goto out;

	br = read(d->client_fd, req, sizeof(*req));
	if (br < 0 && errno == EAGAIN) {
		d->more_data = 0;
	} else if (br != sizeof(*req)) {
		d->more_data = 0;
		rc = -EIO;
	} else {
		rc = 0;
	}

out:
	pthread_mutex_unlock(&d->lock);

	return rc;
}

static int send_response(struct debug_data *d, const struct dbg_response *resp)
{
	ssize_t bs;
	struct iovec iov = {
		.iov_base = (void *)resp,
		.iov_len = sizeof(*resp)
	};

	bs = writev(d->client_fd, &iov, 1);
	if (bs < 0 && errno == EAGAIN)
		return -EAGAIN;
	else if (bs != sizeof(*resp))
		return -EIO;

	return 0;
}

static int dbg_get_calltf(char *user_data)
{
	vpiHandle systfref, args_iter;
	int i, data[D_ARR_SZ];
	struct t_vpi_value argval = {
		.format = vpiIntVal,
	};
	struct debug_data *debug_data = (struct debug_data *)user_data;
	struct dbg_request req;
	struct dbg_response resp;

	systfref = vpi_handle(vpiSysTfCall, NULL);
	args_iter = vpi_iterate(vpiArgument, systfref);

	if (!debug_data->more_data)
		if(__sync_val_compare_and_swap(&debug_data->pending, 1, 0) == 0)
			debug_data->more_data = 1;

	data[D_REQ] = get_request(debug_data, &req) == 0;
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
		send_response(debug_data, &resp);
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
	struct debug_data *debug_data = (struct debug_data *)user_data;
	struct dbg_response resp;

	systfref = vpi_handle(vpiSysTfCall, NULL);
	args_iter = vpi_iterate(vpiArgument, systfref);

	vpiHandle argh = vpi_scan(args_iter);
	vpi_get_value(argh, &argval);

	resp.status = 0;
	resp.data = argval.value.integer;
	send_response(debug_data, &resp);

	vpi_free_object(args_iter);

	return 0;
}

static void enable_reuseaddr(int fd)
{
	int val = 1;

	if (setsockopt(fd, SOL_SOCKET, SO_REUSEADDR, &val, sizeof(val)))
		err(1, "failed to enable SO_REUSEADDR");
}

static int spawn_server(void)
{
	struct addrinfo *result, *rp, hints = {
		.ai_family	= AF_INET,
		.ai_socktype	= SOCK_STREAM,
		.ai_flags	= AI_PASSIVE,
	};
	int s, fd;

	s = getaddrinfo(NULL, "36000", &hints, &result);
	if (s)
		err(1, "getaddrinfo failed");

	for (rp = result; rp; rp = rp->ai_next) {
		fd = socket(rp->ai_family, rp->ai_socktype, rp->ai_protocol);
		if (fd < 0)
			continue;

		enable_reuseaddr(fd);

		if (!bind(fd, rp->ai_addr, rp->ai_addrlen))
			break;

		close(fd);
	}

	if (!rp)
		err(1, "failed to bind server");

	freeaddrinfo(result);

	if (listen(fd, 1))
		err(1, "failed to listen on socket");

	return fd;
}

static int establish_connection(struct debug_data *data)
{
	struct epoll_event event = {
		.events = EPOLLIN | EPOLLRDHUP | EPOLLET,
		.data.ptr = data,
	};
	int client = accept4(data->sock_fd, NULL, NULL, SOCK_NONBLOCK);
	if (client < 0)
		return -EAGAIN;

	if (epoll_ctl(data->epoll_fd, EPOLL_CTL_ADD, client, &event)) {
		warn("failed to add client to epoll (%d)", client);
		close(client);
		return -EAGAIN;
	}

	pthread_mutex_lock(&data->lock);
	data->client_fd = client;
	pthread_mutex_unlock(&data->lock);

	return 0;
}

static void close_connection(struct debug_data *data)
{
	epoll_ctl(data->epoll_fd, EPOLL_CTL_DEL, data->client_fd, NULL);

	pthread_mutex_lock(&data->lock);
	shutdown(data->client_fd, SHUT_RDWR);
	close(data->client_fd);
	data->client_fd = -1;
	pthread_mutex_unlock(&data->lock);
}

static void *server_thread(void *d)
{
	struct debug_data *data = d;

	for (;;) {
		if (establish_connection(d))
			continue;

		for (;;) {
			struct epoll_event revent;
			int nevents;

			nevents = epoll_wait(data->epoll_fd, &revent, 1, -1);
			if (nevents < 0)
				err(1, "epoll_wait() failed");

			if (nevents) {
				if (revent.events & (EPOLLRDHUP | EPOLLHUP))
					break;

				if (revent.events & EPOLLIN)
					__sync_val_compare_and_swap(&data->pending, 0, 1);
			}
		}

		close_connection(data);
	}

	return NULL;
}

static struct debug_data *start_server(void)
{
	pthread_t thread;
	struct debug_data *data;

	data = calloc(1, sizeof(*data));
	if (!data)
		err(1, "failed to allocate data");

	data->sock_fd = spawn_server();
	data->epoll_fd = epoll_create(1);
	data->client_fd = -1;
	if (data->epoll_fd < 0)
		err(1, "failed to create epoll fd");
	pthread_mutex_init(&data->lock, NULL);

	if (pthread_create(&thread, NULL, server_thread, data))
		err(1, "failed to spawn server thread");

	return data;
}

static void debug_stub_register(void)
{
	struct debug_data *data;
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
	};
	int i;

	data = start_server();

	for (i = 0; i < ARRAY_SIZE(tasks); ++i) {
		tasks[i].user_data = (char *)data;
		vpi_register_systf(&tasks[i]);
	}
}

void (*vlog_startup_routines[])(void) = {
	debug_stub_register,
	NULL
};
