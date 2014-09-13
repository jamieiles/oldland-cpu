#define _GNU_SOURCE
#include <assert.h>
#include <stdio.h>
#include <stdlib.h>

#include "spi_sdcard.h"

struct spi_sdcard {
};

struct spi_sdcard *spi_sdcard_new(const char *path)
{
	struct spi_sdcard *card;

	card = calloc(1, sizeof(*card));
	assert(card != NULL);

	return card;
}

uint8_t spi_sdcard_next_byte_to_master(struct spi_sdcard *sd)
{
	static uint8_t next = 0xaa;
	(void)sd;

	return next++;
}

void spi_sdcard_next_byte_to_slave(struct spi_sdcard *sd, uint8_t v)
{
	(void)sd;
	(void)v;
}
