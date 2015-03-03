#define _GNU_SOURCE
#include <assert.h>
#include <err.h>
#include <errno.h>
#include <fcntl.h>
#include <libgen.h>
#include <netdb.h>
#include <pthread.h>
#include <stdarg.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#include <sys/epoll.h>
#include <sys/uio.h>
#include <sys/socket.h>
#include <sys/types.h>

#include "cpu.h"
#include "internal.h"

#include "../debugger/protocol.h"
#include "../devicemodels/jtag.h"

static int sim_interactive = 0;

int sim_is_interactive(void)
{
	return sim_interactive;
}

struct debug_data {
	struct jtag_debug_data *jtag;

	bool breakpoint_hit;
	uint32_t debug_regs[4];
};

static enum {
	SIM_STATE_STOPPED,
	SIM_STATE_RUNNING,
} sim_state = SIM_STATE_RUNNING;

static void handle_req(struct debug_data *debug, struct dbg_request *req,
		       struct cpu *cpu)
{
	struct dbg_response resp = { .status = req->addr > 3 ? -EINVAL : 0 };
	int tlb_miss = 0;

	if (!req->read_not_write)
		debug->debug_regs[req->addr & 0x3] = req->value;

	if (req->addr == REG_CMD && !req->read_not_write) {
		switch (debug->debug_regs[REG_CMD]) {
		case CMD_STOP:
			sim_state = SIM_STATE_STOPPED;
			cpu_read_reg(cpu, PC, &debug->debug_regs[REG_RDATA]);
			break;
		case CMD_RUN:
			sim_state = SIM_STATE_RUNNING;
			break;
		case CMD_STEP:
			sim_state = SIM_STATE_STOPPED;
			debug->breakpoint_hit = false;
			cpu_cycle(cpu, &debug->breakpoint_hit);
			cpu_read_reg(cpu, PC, &debug->debug_regs[REG_RDATA]);
			break;
		case CMD_READ_REG:
			resp.status = cpu_read_reg(cpu,
						   debug->debug_regs[REG_ADDRESS],
						   &debug->debug_regs[REG_RDATA]);
			break;
		case CMD_WRITE_REG:
			resp.status = cpu_write_reg(cpu,
						    debug->debug_regs[REG_ADDRESS],
						    debug->debug_regs[REG_WDATA]);
			break;
		case CMD_RMEM32:
			resp.status = cpu_read_mem(cpu,
						   debug->debug_regs[REG_ADDRESS],
						   &debug->debug_regs[REG_RDATA],
						   32, &tlb_miss);
			if (tlb_miss && !resp.status)
				resp.status = -1;
			break;
		case CMD_WMEM32:
			resp.status = cpu_write_mem(cpu,
						    debug->debug_regs[REG_ADDRESS],
						    debug->debug_regs[REG_WDATA],
						    32);
			break;
		case CMD_RMEM16:
			resp.status = cpu_read_mem(cpu,
						   debug->debug_regs[REG_ADDRESS],
						   &debug->debug_regs[REG_RDATA],
						   16, &tlb_miss);
			if (tlb_miss && !resp.status)
				resp.status = -1;
			break;
		case CMD_WMEM16:
			resp.status = cpu_write_mem(cpu,
						    debug->debug_regs[REG_ADDRESS],
						    debug->debug_regs[REG_WDATA],
						    16);
			break;
		case CMD_RMEM8:
			resp.status = cpu_read_mem(cpu,
						   debug->debug_regs[REG_ADDRESS],
						   &debug->debug_regs[REG_RDATA],
						   8, &tlb_miss);
			if (tlb_miss && !resp.status)
				resp.status = -1;
			break;
		case CMD_WMEM8:
			resp.status = cpu_write_mem(cpu,
						    debug->debug_regs[REG_ADDRESS],
						    debug->debug_regs[REG_WDATA],
						    8);
			break;
		case CMD_RESET:
			cpu_reset(cpu);
			break;
		case CMD_CACHE_SYNC:
			cpu_cache_sync(cpu);
			break;
		case CMD_CPUID:
			debug->debug_regs[REG_RDATA] =
				cpu_cpuid(debug->debug_regs[REG_ADDRESS]);
			break;
		case CMD_GET_EXEC_STATUS:
			debug->debug_regs[REG_RDATA] =
				(sim_state == SIM_STATE_RUNNING) |
				((!!debug->breakpoint_hit) << 1);
			break;
		case CMD_SIM_TERM:
			exit(EXIT_SUCCESS);
		default:
			resp.status = -EINVAL;
		}
	}

	if (req->read_not_write)
		resp.data = debug->debug_regs[req->addr & 0x3];

	send_response(debug->jtag, &resp);
}

int main(int argc, char *argv[])
{
	struct cpu *cpu;
	struct debug_data debug;
	int i, cpu_flags = CPU_NOTRACE;
	const char *bootrom_image = ROM_FILE;
	const char *sdcard_image = NULL;

	debug.jtag = start_server();

	for (i = 0; i < argc; ++i) {
		if (!strcmp(argv[i], "--debug") ||
		    !strcmp(argv[i], "-d"))
			cpu_flags &= ~CPU_NOTRACE;
		if (!strcmp(argv[i], "--interactive"))
			sim_interactive = 1;
		if (!strcmp(argv[i], "--bootrom") && i + 1 < argc) {
			bootrom_image = argv[i + 1];
			++i;
		}
		if (!strcmp(argv[i], "--sdcard") && i + 1 < argc) {
			sdcard_image = argv[i + 1];
			++i;
		}
	}

	cpu = new_cpu(NULL, cpu_flags, bootrom_image, sdcard_image);

	notify_runner();

	for (;;) {
		struct dbg_request req;

		if (!debug.jtag->more_data &&
		    __sync_val_compare_and_swap(&debug.jtag->pending, 1, 0) == 0)
			debug.jtag->more_data = 1;

		if (!get_request(debug.jtag, &req))
			handle_req(&debug, &req, cpu);

		if (sim_state == SIM_STATE_RUNNING) {
			debug.breakpoint_hit = false;
			cpu_cycle(cpu, &debug.breakpoint_hit);
			if (debug.breakpoint_hit)
				sim_state = SIM_STATE_STOPPED;
		}
	}

	return 0;
}
