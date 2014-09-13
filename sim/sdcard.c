#define _GNU_SOURCE
#include <assert.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>

#include "sdcard.h"

#include "../devicemodels/spi_sdcard.h"

static void sdcard_exchange_bytes(struct spislave *slave,
				  uint8_t master_to_slave,
				  uint8_t *slave_to_master)
{
	struct spi_sdcard *sdcard = slave->privdata;

	spi_sdcard_next_byte_to_slave(sdcard, master_to_slave);
	*slave_to_master = spi_sdcard_next_byte_to_master(sdcard);
}

struct spislave *sdcard_new(const char *sdcard_image)
{
	struct spislave *slave;
	struct spi_sdcard *sdcard;

	sdcard = spi_sdcard_new(sdcard_image);
	assert(sdcard != NULL);

	slave = calloc(1, sizeof(*slave));
	assert(slave != NULL);
	slave->privdata = sdcard;
	slave->exchange_bytes = sdcard_exchange_bytes;

	return slave;
}
