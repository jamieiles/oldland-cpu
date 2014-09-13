#define _GNU_SOURCE

#include <assert.h>
#include <err.h>
#include <errno.h>
#include <fcntl.h>
#include <poll.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <termios.h>
#include <unistd.h>

#include <vpi_user.h>

static int spislave_compiletf(char *user_data)
{
	return 0;
}

static void spi_master_to_slave(uint8_t cs, uint8_t val)
{
	(void)cs;
	(void)val;
}

static void spi_slave_to_master(uint8_t cs, uint8_t *val)
{
	(void)cs;

	*val = 0;
}

static int spislave_master_to_slave_calltf(char *user_data)
{
	vpiHandle systfref, args_iter, argh;
	struct t_vpi_value argval;
	uint8_t cs, val;

	systfref = vpi_handle(vpiSysTfCall, NULL);
	args_iter = vpi_iterate(vpiArgument, systfref);
	argval.format = vpiIntVal;

	argh = vpi_scan(args_iter);
	vpi_get_value(argh, &argval);
	cs = argval.value.integer;

	argh = vpi_scan(args_iter);
	vpi_get_value(argh, &argval);
	val = argval.value.integer;

	spi_master_to_slave(cs, val);

	vpi_free_object(args_iter);

	return 0;
}

static int spislave_slave_to_master_calltf(char *user_data)
{
	vpiHandle systfref, args_iter, argh;
	struct t_vpi_value argval;
	uint8_t cs, val = 0;

	systfref = vpi_handle(vpiSysTfCall, NULL);
	args_iter = vpi_iterate(vpiArgument, systfref);
	argval.format = vpiIntVal;

	argh = vpi_scan(args_iter);
	vpi_get_value(argh, &argval);
	cs = argval.value.integer;

	spi_slave_to_master(cs, &val);

	argh = vpi_scan(args_iter);
	argval.value.integer = val;
	vpi_put_value(argh, &argval, NULL, vpiNoDelay);

	vpi_free_object(args_iter);

	return 0;
}

static void spislave_register(void)
{
	s_vpi_systf_data get = {
		.type		= vpiSysTask,
		.tfname		= "$spi_get_next_byte_to_master",
		.calltf		= spislave_slave_to_master_calltf,
		.compiletf	= spislave_compiletf,
		.sizetf		= 0,
	};
	s_vpi_systf_data put = {
		.type		= vpiSysTask,
		.tfname		= "$spi_rx_byte_from_master",
		.calltf		= spislave_master_to_slave_calltf,
		.compiletf	= spislave_compiletf,
		.sizetf		= 0,
	};

	vpi_register_systf(&get);
	vpi_register_systf(&put);
}

void (*vlog_startup_routines[])(void) = {
	spislave_register,
	NULL
};
