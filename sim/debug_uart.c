/*
 * Debug uart.  By default there is no input data and all output data goes to
 * uart_tx.txt.  If the OLDLAND_UART_SOCK environment variable is set with a
 * path to a unix domain socket then that socket is used to read/write UART
 * data.
 */
#include <assert.h>
#include <errno.h>
#include <fcntl.h>
#include <poll.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

#include <sys/socket.h>
#include <sys/un.h>

#include "internal.h"
#include "io.h"

enum reg_map {
	UART_DATA_REG		= 0x0,
	UART_STATUS_REG		= 0x4,
};

enum {
	UART_STATUS_TX_EMPTY	= (1 << 0),
	UART_STATUS_RX_RDY	= (1 << 1),
};

struct uart {
	int fd;
};

static int uart_write(unsigned int offs, uint32_t val, size_t nr_bits,
		      void *priv)
{
	struct uart *u = priv;
	char c = val & 0xff;
	ssize_t bw;

	if (nr_bits != 32)
		return -EFAULT;

	if (offs == UART_DATA_REG) {
		bw = write(u->fd, &c, 1);
		(void)bw;
	}

	return 0;
}

static int uart_read(unsigned int offs, uint32_t *val, size_t nr_bits,
		     void *priv)
{
	struct uart *u = priv;
	uint32_t regval= 0;

	if (nr_bits != 32)
		return -EFAULT;

	if (offs == UART_STATUS_REG) {
		struct pollfd pfd = {
			.fd = u->fd,
			.events = POLLIN | POLLOUT,
		};

		if (poll(&pfd, 1, 0)) {
			if (pfd.revents & POLLIN)
				regval |= UART_STATUS_RX_RDY;
			if (pfd.revents & POLLOUT)
				regval |= UART_STATUS_TX_EMPTY;
		}
	} else if (offs == UART_DATA_REG) {
		char c = 0;

		if (read(u->fd, &c, 1) == 1) {
			regval = c;
		}
	}

	*val = regval;

	return 0;
}

static struct io_ops uart_io_ops = {
	.write = uart_write,
	.read = uart_read,
};

int debug_uart_init(struct mem_map *mem, physaddr_t base, size_t len)
{
	struct region *r;
	struct uart *u;
	const char *sock = getenv("OLDLAND_UART_SOCK");

	u = malloc(sizeof(*u));
	assert(u);

	if (!sock) {
		u->fd = open("uart_tx.txt", O_WRONLY | O_CREAT | O_NONBLOCK,
			     0600);
		assert(u->fd >= 0);
	} else {
		struct sockaddr_un addr;
		int len;

		u->fd = socket(AF_UNIX, SOCK_STREAM, 0);
		assert(u->fd >= 0);

		addr.sun_family = AF_UNIX;
		strncpy(addr.sun_path, sock, sizeof(addr.sun_path));
		addr.sun_path[sizeof(addr.sun_path) - 1] = '\0';
		len = strlen(addr.sun_path) + sizeof(addr.sun_family);
		if (connect(u->fd, (struct sockaddr *)&addr, len) < 0)
			die("failed to connect to uart socket %s\n", sock);
	}

	r = mem_map_region_add(mem, base, len, &uart_io_ops, u);
	assert(r != NULL);

	return 0;
}
