#include <assert.h>
#include <errno.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "internal.h"
#include "io.h"
#include "spimaster.h"

#define SPIMASTER_NUM_REGS ((SPI_XFER_CONTROL_REG_OFFS + 4) / 4)

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
	master->loopback_enabled = master->regs[SPI_CONTROL_REG_OFFS / 4] &
                SPI_LOOPBACK_ENABLE_MASK;
	master->xfer_length = master->regs[SPI_XFER_CONTROL_REG_OFFS / 4] & 0xffff;
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

		if (regnum == SPI_XFER_CONTROL_REG_OFFS / 4)
			spimaster_start_xfer(master);
	} else if (offs >= 8192) {
		memcpy(master->xfer_buf + offs - 8192, &val, nr_bits / 8);
	}

	return 0;
}

static uint8_t slave_xfer(struct spimaster *master, struct spislave *slave)
{
	uint8_t slave_to_master = 0;

	assert(slave->exchange_bytes);
	slave->exchange_bytes(slave, master->xfer_buf[master->bytes_xfered],
			      &slave_to_master);

	return slave_to_master;
}

static void xfer_slaves(struct spimaster *master)
{
	unsigned int m;
	uint8_t v = 0;

	for (m = 0; m < master->nr_slaves; ++m)
		if (master->regs[SPI_CS_ENABLE_REG_OFFS / 4] & (1 << m) &&
		    master->slaves[m])
			/* Slaves share a common bus. */
			v |= slave_xfer(master, master->slaves[m]);

	master->xfer_buf[master->bytes_xfered] = v;
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
	else
		xfer_slaves(master);
	master->bytes_xfered++;
}

static void spimaster_compute_busy(struct spimaster *master)
{
	master->regs[SPI_XFER_CONTROL_REG_OFFS / 4] &= ~XFER_BUSY_MASK;
	if (master->bytes_xfered != master->xfer_length)
		master->regs[SPI_XFER_CONTROL_REG_OFFS / 4] |= XFER_BUSY_MASK;
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
	assert(nr_slaves <= sizeof(unsigned int) * 8);

	r = mem_map_region_add(mem, base, 16384, &spimaster_ops, master, 0);
	assert(r);

	return master;
}
