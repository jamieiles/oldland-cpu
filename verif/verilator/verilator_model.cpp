#include <cassert>
#include <unistd.h>

#include <verilated.h>
#include "Vverilator_toplevel.h"
#include "../devicemodels/jtag.h"

static struct jtag_debug_data *jtag_debug_data;

void uart_get(SData *val)
{
	*val = 0;
}

void uart_put(SData val)
{
	char c = val & 0xff;

	ssize_t bw = write(STDOUT_FILENO, &c, 1);
	assert(bw == 1);
}

void dbg_sim_term(IData val)
{
	(void)val;
	exit(EXIT_SUCCESS);
}

void dbg_put(IData val)
{
	struct dbg_response resp;

	resp.status = 0;
	resp.data = val;
	send_response(jtag_debug_data, &resp);
}

void dbg_get(CData *req, CData *rnw, CData *addr, IData *val)
{
	struct dbg_request dbg_req;

	if (!jtag_debug_data->more_data)
		if(__sync_val_compare_and_swap(&jtag_debug_data->pending, 1, 0) == 0)
			jtag_debug_data->more_data = 1;

	if (jtag_debug_data->more_data) {
		*req = get_request(jtag_debug_data, &dbg_req) == 0;
		jtag_debug_data->more_data = *req;
	}

	*rnw = dbg_req.read_not_write;
	*addr = dbg_req.addr;
	*val = dbg_req.value;

	if (*req && !*rnw) {
		struct dbg_response resp;

		resp.status = 0;
		send_response(jtag_debug_data, &resp);
	}
}

void spi_rx_byte_from_master(IData cs, CData val)
{
	(void)cs;
	(void)val;
}

void spi_get_next_byte_to_master(IData cs, CData *val)
{
	(void)cs;
	*val = 0;
}

static void init_debug()
{
	jtag_debug_data = start_server();
	assert(jtag_debug_data != NULL);
	notify_runner();
}

int main(int argc, char **argv)
{
	Verilated::commandArgs(argc, argv);

	Vverilator_toplevel *top = new Vverilator_toplevel;

	init_debug();

	top->clk = 0;
	top->dbg_clk = 0;

	while (!Verilated::gotFinish()) {
		top->eval();
		top->clk = !top->clk;
		top->dbg_clk = !top->dbg_clk;
	}

	top->final();

	delete top;

	return EXIT_SUCCESS;
}
