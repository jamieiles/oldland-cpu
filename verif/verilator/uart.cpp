#include <err.h>
#include <string>
#include <verilated.h>
#include <unistd.h>
#include "../../devicemodels/uart.h"

static int pts;

extern "C" int sim_is_interactive(void)
{
	std::string match = Verilated::commandArgsPlusMatch("interactive");

	return match != "";
}

void init_uart()
{
	pts = create_pts();
	if (pts < 0)
		err(1, "failed to create pts");
}

void uart_get(SData *val)
{
	char c;

	if (read(pts, &c, 1) == 1)
		*val = (1 << 8) | c;
	else
		*val = 0;
}

void uart_put(SData val)
{
	char c = val & 0xff;

	ssize_t bw = write(sim_is_interactive() ? pts : STDOUT_FILENO, &c, 1);
	assert(bw == 1);
}
