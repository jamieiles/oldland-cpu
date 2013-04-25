#include <assert.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>

#include "io.h"

enum sim_status {
	SIM_SUCCESS = 0xffffffff,
	SIM_FAIL = 0xfffffffe,
	SIM_CONTINUE = 0x00000000,
};

struct cpu {
	uint32_t pc;
	uint32_t next_pc;
	uint32_t regs[8];
	unsigned z:1;
	unsigned c:1;

	struct mem_map *mem;
};

static struct cpu *new_cpu(const char *romfile)
{
	int err;
	struct cpu *c = calloc(1, sizeof(*c));

	assert(c);
	c->mem = mem_map_new();
	assert(c->mem);

	err = rom_init(c->mem, 0x00000000, 0x1000, romfile);
	assert(!err);

	err = ram_init(c->mem, 0x10000000, 0x10000);
	assert(!err);

	err = debug_uart_init(c->mem, 0x80000000, 0x1000);
	assert(!err);

	return c;
}

static uint32_t cpu_cycle(struct cpu *c)
{
	uint32_t instr;
	int err;

	c->next_pc = c->pc + 4;

	err = mem_map_read(c->mem, c->pc, 32, &instr);
	assert(!err);

	if (instr == SIM_SUCCESS || instr == SIM_FAIL)
		return instr;

	printf("executing instruction %08x\n", instr);
	c->pc = c->next_pc;

	return SIM_CONTINUE;
}

int main(void)
{
	struct cpu *c = new_cpu("rom.bin");
	int err;

	printf("Oldland CPU simulator\n");

	do {
		err = cpu_cycle(c);
	} while (err == 0);

	printf("[%s]\n", err == SIM_SUCCESS ? "SUCCESS" : "FAIL");

	return err == SIM_SUCCESS ? EXIT_SUCCESS : EXIT_FAILURE;
}
