#ifndef __PROTOCOL_H__
#define __PROTOCOL_H__

#include <stdint.h>

enum dbg_cmd {
	CMD_STOP,
	CMD_RUN,
	CMD_STEP,
	CMD_READ_REG,
	CMD_WRITE_REG,
};

enum dbg_reg {
	REG_CMD,	/* Command register. */
	REG_ADDRESS,	/* Address register. */
	REG_WDATA,	/* Write data (write-only). */
	REG_RDATA,	/* Read data (read-only). */
};

struct dbg_request {
	uint32_t addr;
	uint32_t value;
	uint8_t read_not_write;
};

struct dbg_response {
	int32_t status;
	uint32_t data;
};

#endif /* __PROTOCOL_H__ */
