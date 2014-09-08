#include <assert.h>
#include <errno.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "internal.h"
#include "io.h"
#include "spimaster.h"

enum spimaster_regs {
	SPIMASTER_CONTROL	= 0x0,
	SPIMASTER_CS_ENABLE	= 0x1,
	SPIMASTER_XFER_CONTROL	= 0x2,
	SPIMASTER_NUM_REGS
};

#define CONTROL_LOOPBACK_ENABLE_OFFS	9
#define XFER_CONTROL_BUSY_OFFS		17
#define XFER_CONTROL_GO_OFFS		16

struct spimaster {
	struct spislave **slaves;
	unsigned int nr_slaves;
	uint32_t regs[SPIMASTER_NUM_REGS];

	bool loopback_enabled;
	uint16_t xfer_length;
	uint16_t bytes_xfered;

	uint8_t __attribute__((aligned(4))) xfer_buf[8192];
};

static void spimaster_start_xfer(struct spimaster *master)
{
	master->loopback_enabled = master->regs[SPIMASTER_CONTROL] &
		(1 << CONTROL_LOOPBACK_ENABLE_OFFS);
	master->xfer_length = master->regs[SPIMASTER_XFER_CONTROL] & 0xffff;
	master->bytes_xfered = 0;
}

static int spimaster_write(unsigned int offs, uint32_t val, size_t nr_bits,
			   void *priv)
{
	struct spimaster *master = priv;
	unsigned int regnum = offs >> 2;

	if (regnum < SPIMASTER_NUM_REGS) {
		if (nr_bits != 32)
			return -EFAULT;
		master->regs[regnum] = val;

		if (regnum == SPIMASTER_XFER_CONTROL)
			spimaster_start_xfer(master);
	} else if (offs >= 8192) {
		memcpy(master->xfer_buf + offs - 8192, &val, nr_bits / 8);
	}

	return 0;
}

/*
 * Transfer a byte every time the master is read to exercise polling.
 */
static void spimaster_xfer_byte(struct spimaster *master)
{
	if (master->bytes_xfered >= master->xfer_length)
		return;
	if (master->loopback_enabled)
		master->xfer_buf[master->bytes_xfered] ^= 0xff;
	master->bytes_xfered++;
}

static void spimaster_compute_busy(struct spimaster *master)
{
	master->regs[SPIMASTER_XFER_CONTROL] &= ~(1 << XFER_CONTROL_BUSY_OFFS);
	if (master->bytes_xfered != master->xfer_length)
		master->regs[SPIMASTER_XFER_CONTROL] |= (1 << XFER_CONTROL_BUSY_OFFS);
}

static void spimaster_update_regs(struct spimaster *master)
{
	spimaster_xfer_byte(master);
	spimaster_compute_busy(master);
}

static int spimaster_read(unsigned int offs, uint32_t *val, size_t nr_bits,
			  void *priv)
{
	struct spimaster *master = priv;
	unsigned int regnum = offs >> 2;

	spimaster_update_regs(master);

	if (regnum < SPIMASTER_NUM_REGS) {
		if (nr_bits != 32)
			return -EFAULT;

		*val = master->regs[regnum];
	} else if (offs >= 8192) {
		memcpy(val, master->xfer_buf + offs - 8192, nr_bits / 8);
	}

	return 0;
}

static const struct io_ops spimaster_ops = {
	.write = spimaster_write,
	.read = spimaster_read,
};

struct spimaster *spimaster_init(struct mem_map *mem, physaddr_t base,
				 struct spislave **slaves, size_t nr_slaves)
{
	struct region *r;
	struct spimaster *master;

	master = calloc(1, sizeof(*master));
	assert(master);

	master->slaves = slaves;
	master->nr_slaves = nr_slaves;

	r = mem_map_region_add(mem, base, 16384, &spimaster_ops, master, 0);
	assert(r);

	return master;
}
