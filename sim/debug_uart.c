#include <assert.h>
#include <stdio.h>

#include "io.h"

static int uart_write(unsigned int offs, uint32_t val, size_t nr_bits,
		      void *priv)
{
	putchar(val & 0xff);
	fflush(stdout);

	return 0;
}

static int uart_read(unsigned int offs, uint32_t *val, size_t nr_bits,
		     void *priv)
{
	return 0;
}

static struct io_ops uart_io_ops = {
	.write = uart_write,
	.read = uart_read,
};

int debug_uart_init(struct mem_map *mem, physaddr_t base, size_t len)
{
	struct region *r = mem_map_region_add(mem, base, len, &uart_io_ops, NULL);
	assert(r != NULL);

	return 0;
}
