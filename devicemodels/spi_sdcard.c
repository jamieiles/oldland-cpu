#define _GNU_SOURCE
#include <assert.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>

#include "spi_sdcard.h"

#define DATA_BUF_SIZE 1024

#define IN_IDLE_STATE (1 << 0)

enum card_state {
	STATE_READING_COMMAND,
	STATE_RESPONSE,
};

/*
 * Reset sequence:
 * - master sends CMD0
 * - master sends CMD1 to get status until in-idle-state bit == 0.
 *
 * Supported features:
 * - reset
 * - single block read
 * - crc validation
 * - set blocklen
 */
struct spi_command {
	uint8_t command;
	uint8_t argument[4];
	uint8_t crc;
};

struct spi_sdcard {
	union {
		struct spi_command current_cmd;
		uint8_t cmd_buf[sizeof(struct spi_command)];
	};
	char data_buf[DATA_BUF_SIZE];
	unsigned int num_bytes_rx;
	unsigned int num_bytes_tx;
	enum card_state state;
	unsigned int reset_poll_count;
};

struct spi_sdcard *spi_sdcard_new(const char *path)
{
	struct spi_sdcard *card;

	card = calloc(1, sizeof(*card));
	assert(card != NULL);
	card->state = STATE_READING_COMMAND;

	return card;
}

static inline bool command_is_complete(const struct spi_sdcard *sd)
{
	return sd->num_bytes_rx == sizeof(sd->current_cmd);
}

static void read_data(struct spi_sdcard *sd, uint8_t v)
{
	assert(sd->num_bytes_rx < DATA_BUF_SIZE + sizeof(sd->current_cmd));

	if (sd->num_bytes_rx == 0 && !(v & 0x40))
		return;

	if (sd->num_bytes_rx < sizeof(sd->current_cmd))
		sd->cmd_buf[sd->num_bytes_rx] = v;
	else if (sd->num_bytes_rx >= sizeof(sd->current_cmd))
		sd->data_buf[sd->num_bytes_rx] = v;

	sd->num_bytes_rx++;
}

static void process_new_command(struct spi_sdcard *sd)
{
	sd->state = STATE_RESPONSE;
}

static void set_next_state(struct spi_sdcard *sd)
{
	if (command_is_complete(sd))
		process_new_command(sd);
}

void spi_sdcard_next_byte_to_slave(struct spi_sdcard *sd, uint8_t v)
{
	read_data(sd, v);
	set_next_state(sd);
}

static void finish_command(struct spi_sdcard *sd)
{
	sd->state = STATE_READING_COMMAND;
	sd->num_bytes_tx = 0;
	sd->num_bytes_rx = 0;
}

uint8_t spi_sdcard_next_byte_to_master(struct spi_sdcard *sd)
{
	uint8_t v = 0;

	if (sd->state == STATE_RESPONSE) {
		switch (sd->current_cmd.command & 0x3f) {
		case 0:
			sd->reset_poll_count = 0;
			v = IN_IDLE_STATE;
			finish_command(sd);
			break;
		case 1:
			v = sd->reset_poll_count++ >= 1 ? 0 : IN_IDLE_STATE;
			finish_command(sd);
			break;
		default:
			break;
		}
	}

	sd->num_bytes_tx = sd->state == STATE_READING_COMMAND ? 0 : sd->num_bytes_tx + 1;

	return v;
}
