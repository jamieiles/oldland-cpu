#include <cassert>
#include <unistd.h>

#include <verilated.h>
#include "Vverilator_toplevel.h"
#include "debug.h"
#include "uart.h"

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

int main(int argc, char **argv)
{
	Verilated::commandArgs(argc, argv);

	Vverilator_toplevel *top = new Vverilator_toplevel;

	init_uart();
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
