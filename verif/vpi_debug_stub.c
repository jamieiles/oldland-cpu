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
 */
#define _GNU_SOURCE

#include <vpi_user.h>

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

	systfref = vpi_handle(vpiSysTfCall, NULL);
	args_iter = vpi_iterate(vpiArgument, systfref);

	/* Step. */
	data[D_REQ] = 1;
	data[D_RNW] = 0;
	data[D_ADDR] = 0;
	data[D_VALUE] = 2;

	for (i = 0; i < D_ARR_SZ; ++i) {
		vpiHandle argh = vpi_scan(args_iter);
		argval.value.integer = data[i];
		vpi_put_value(argh, &argval, NULL, vpiNoDelay);
	}

	vpi_free_object(args_iter);

	return 0;
}

static int dbg_put_calltf(char *user_data)
{
	return 0;
}

static void debug_stub_register(void)
{
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

	for (i = 0; i < ARRAY_SIZE(tasks); ++i)
		vpi_register_systf(&tasks[i]);
}

void (*vlog_startup_routines[])(void) = {
	debug_stub_register,
	NULL
};
