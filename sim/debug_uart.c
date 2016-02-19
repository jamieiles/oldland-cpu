#include <assert.h>
#include <errno.h>
#include <fcntl.h>
#include <poll.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

#include "internal.h"
#include "io.h"
#include "uart.h"

static int uart_write(unsigned int offs, uint32_t val, size_t nr_bits,
		      void *priv)
{
	struct uart_data *u = priv;
	char c = val & 0xff;
	ssize_t bw;

	if (nr_bits != 32)
		return -EFAULT;

	if (offs == UART_DATA_REG_OFFS) {
		bw = write(u->fd, &c, 1);
		(void)bw;
	}

	return 0;
}

static int uart_read(unsigned int offs, uint32_t *val, size_t nr_bits,
		     void *priv)
{
	struct uart_data *u = priv;
	uint32_t regval= 0;

	if (nr_bits != 32)
		return -EFAULT;

	if (offs == UART_STATUS_REG_OFFS) {
		struct pollfd pfd = {
			.fd = u->fd,
			.events = POLLIN | POLLOUT,
			.revents = 0
		};

		if (poll(&pfd, 1, 0)) {
#ifndef EMSCRIPTEN
			if (pfd.revents & POLLIN)
				regval |= RX_READY_MASK;
#else
			char c;
			if (!u->next_rx_valid && read(STDIN_FILENO, &c, 1) == 1) {
				u->next_rx = c;
				u->next_rx_valid = true;
			}

			if (u->next_rx_valid)
				regval |= RX_READY_MASK;
#endif
			if (pfd.revents & POLLOUT)
				regval |= TX_EMPTY_MASK;
		}
	} else if (offs == UART_DATA_REG_OFFS) {
		char c = 0;

#ifdef EMSCRIPTEN
		if (u->next_rx_valid) {
			regval = u->next_rx;
			u->next_rx_valid = false;
		} else if (read(STDIN_FILENO, &c, 1) == 1)
			regval = c;
#else
		if (read(u->fd, &c, 1) == 1)
			regval = c;
#endif
	}

	*val = regval;

	return 0;
}

static const struct io_ops uart_io_ops = {
	.write = uart_write,
	.read = uart_read,
};

int debug_uart_init(struct mem_map *mem, physaddr_t base, size_t len)
{
	struct region *r;
	struct uart_data *u;

	u = malloc(sizeof(*u));
	assert(u);

	if (sim_is_interactive()) {
		u->fd = create_pts();
		assert(u->fd >= 0);
	} else {
		u->fd = STDOUT_FILENO;
	}

	r = mem_map_region_add(mem, base, len, &uart_io_ops, u, 0);
	assert(r != NULL);

	return 0;
}
