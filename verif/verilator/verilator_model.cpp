#include <cassert>
#include <iostream>
#include <unistd.h>

#include <verilated.h>
#include "Vverilator_toplevel.h"
#include <verilated_vcd_c.h>

#include "debug.h"
#include "uart.h"
#include "spi.h"

class TopLevel {
public:
	TopLevel();
	~TopLevel();
	void set_tracer(VerilatedVcdC *tracer);
	void cycle();
private:
	VerilatedVcdC *tracer;
	Vverilator_toplevel *top;
	vluint64_t cur_time;
};

TopLevel::TopLevel()
	: tracer(NULL), top(new Vverilator_toplevel), cur_time(0)
{
	init_uart();
	init_debug();
	init_spi();

	top->clk = 0;
	top->dbg_clk = 0;
}

TopLevel::~TopLevel()
{
#ifdef VERILATOR_TRACE
	if (tracer)
		tracer->close();
#endif /* VERILATOR_TRACE */
	top->final();
}

void TopLevel::set_tracer(VerilatedVcdC *tracer)
{
#ifdef VERILATOR_TRACE
	Verilated::traceEverOn(true);
	top->trace(tracer, 99);
	this->tracer = tracer;
	tracer->open("trace.vcd");
#endif /* VERILATOR_TRACE */
}

void TopLevel::cycle()
{
	top->eval();
	top->clk = !top->clk;
	top->dbg_clk = !top->dbg_clk;
#ifdef VERILATOR_TRACE
	if (tracer)
		tracer->dump(cur_time++);
#endif /* VERILATOR_TRACE */
}

int main(int argc, char **argv)
{
	Verilated::commandArgs(argc, argv);
	TopLevel top;

#ifdef VERILATOR_TRACE
	VerilatedVcdC tracer;
	top.set_tracer(&tracer);
#endif /* VERILATOR_TRACE */

	while (!Verilated::gotFinish())
		top.cycle();

	return EXIT_SUCCESS;
}
