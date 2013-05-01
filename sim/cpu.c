#define _GNU_SOURCE
#include <assert.h>
#include <libgen.h>
#include <stdarg.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#include "cpu.h"
#include "internal.h"
#include "io.h"
#include "trace.h"
#include "oldland-types.h"

struct cpu {
	uint32_t pc;
	uint32_t next_pc;
	uint32_t regs[8];
	union {
		uint32_t flagsw;
		struct {
			unsigned z:1;
			unsigned c:1;
		} flagsbf;
	};

	struct mem_map *mem;
	FILE *trace_file;
	unsigned long long cycle_count;
};

enum instruction_class {
	INSTR_ARITHMETIC,
	INSTR_BRANCH,
	INSTR_LDR_STR,
	INSTR_MISC,
};

static inline enum instruction_class instr_class(uint32_t instr)
{
	return (instr >> 30) & 0x3;
}

static inline unsigned instr_opc(uint32_t instr)
{
	return (instr >> 26) & 0xf;
}

static inline enum regs instr_rd(uint32_t instr)
{
	return (instr >> 6) & 0x7;
}

static inline enum regs instr_ra(uint32_t instr)
{
	return (instr >> 3) & 0x7;
}

static inline enum regs instr_rb(uint32_t instr)
{
	return instr & 0x7;
}

static inline uint16_t instr_imm16(uint32_t instr)
{
	return (instr >> 10) & 0xffff;
}

static inline uint32_t instr_imm24(uint32_t instr)
{
	return instr & 0xffffff;
}

static void cpu_wr_reg(struct cpu *c, enum regs r, uint32_t v)
{
	trace(c->trace_file, TRACE_R0 + r, v);
	c->regs[r] = v;
}

static void cpu_set_next_pc(struct cpu *c, uint32_t v)
{
	c->next_pc = v;
}

struct cpu *new_cpu(const char *test_file, const char *binary)
{
	int err;
	struct cpu *c;

	c = calloc(1, sizeof(*c));
	assert(c);
	c->trace_file = init_trace_file();

	c->mem = mem_map_new();
	assert(c->mem);

	err = ram_init(c->mem, 0x00000000, 0x10000, binary);
	assert(!err);

	err = debug_uart_init(c->mem, 0x80000000, 0x1000);
	assert(!err);

	return c;
}

static void emul_arithmetic(struct cpu *c, uint32_t instr)
{
	enum regs ra, rb, rd;
	uint16_t imm16;
	uint32_t op2;

	ra = instr_ra(instr);
	rb = instr_rb(instr);
	rd = instr_rd(instr);
	imm16 = instr_imm16(instr);
	op2 = (instr & (1 << 9)) ? c->regs[rb] : imm16;

	switch (instr_opc(instr)) {
	case OPCODE_ADD:
		cpu_wr_reg(c, rd, c->regs[ra] + op2);
		break;
	case OPCODE_SUB:
		cpu_wr_reg(c, rd, c->regs[ra] - op2);
		break;
	case OPCODE_LSL:
		cpu_wr_reg(c, rd, c->regs[ra] << op2);
		break;
	case OPCODE_LSR:
		cpu_wr_reg(c, rd, c->regs[ra] >> op2);
		break;
	case OPCODE_AND:
		cpu_wr_reg(c, rd, c->regs[ra] & op2);
		break;
	case OPCODE_XOR:
		cpu_wr_reg(c, rd, c->regs[ra] ^ op2);
		break;
	case OPCODE_BIC:
		cpu_wr_reg(c, rd, c->regs[ra] & ~(1 << op2));
		break;
	case OPCODE_OR:
		cpu_wr_reg(c, rd, c->regs[ra] | op2);
		break;
	case OPCODE_MOVHI:
		cpu_wr_reg(c, rd, op2 << 16);
		break;
	case OPCODE_CMP:
		c->flagsbf.z = !(c->regs[ra] - op2);
		trace(c->trace_file, TRACE_FLAGS, c->flagsw);
		break;
	default:
		die("invalid arithmetic opcode %u (%08x)\n", instr_opc(instr),
		    instr);
	}

	if (instr_opc(instr) != OPCODE_MOVHI &&
	    instr_opc(instr) != OPCODE_CMP) {
		c->flagsbf.z = !c->regs[rd];
		trace(c->trace_file, TRACE_FLAGS, c->flagsw);
	}
}

static void emul_branch(struct cpu *c, uint32_t instr)
{
	enum regs rb = instr_rb(instr);
	int32_t imm24 = instr_imm24(instr);
	uint32_t target;

	/* Sign extend the immediate. */
	imm24 <<= 8;
	imm24 >>= 8;

	target = (instr & (1 << 25)) ? rb : c->pc + (imm24 << 2);

	switch (instr_opc(instr)) {
	case OPCODE_B:
		cpu_set_next_pc(c, target);
		break;
	case OPCODE_BEQ:
		if (c->flagsbf.z)
			cpu_set_next_pc(c, target);
		break;
	default:
		die("invalid branch opcode %u (%08x)\n", instr_opc(instr),
		    instr);
	}
}

extern void cpu_mem_write_hook(struct cpu *c, physaddr_t addr,
			       unsigned int nr_bits, uint32_t val);

static int cpu_mem_map_write(struct cpu *c, physaddr_t addr,
			     unsigned int nr_bits, uint32_t val)
{
	trace(c->trace_file, TRACE_DADDR, addr);
	trace(c->trace_file, TRACE_DOUT, val);

	cpu_mem_write_hook(c, addr, nr_bits, val);

	return mem_map_write(c->mem, addr, nr_bits, val);
}

static void emul_ldr_str(struct cpu *c, uint32_t instr)
{
	int32_t imm16 = instr_imm16(instr);
	uint32_t addr, v;
	enum regs ra = instr_ra(instr), rb = instr_rb(instr), rd = instr_rd(instr);
	int err;

	/* PC relative addressing. */
	if (!(instr & (1 << 9))) {
		/* Sign extend. */
		imm16 <<= 16;
		imm16 >>= 16;
		addr = c->pc + imm16;
	} else {
		addr = c->regs[ra] + imm16;
	}

	switch (instr_opc(instr)) {
	case OPCODE_LDR8:
		err = mem_map_read(c->mem, addr, 8, &v);
		if (err)
			die("failed to read 8 bits @%08x\n", addr);
		cpu_wr_reg(c, rd, v & 0xff);
		break;
	case OPCODE_STR8:
		v = c->regs[rb] & 0xff;
		err = cpu_mem_map_write(c, addr, 8, v);
		if (err)
			die("failed to write 8 bits @%08x\n", addr);
		break;
	default:
		die("invalid load/store opcode %u (%08x)\n", instr_opc(instr),
		    instr);
	}
}

static void emul_insn(struct cpu *c, uint32_t instr)
{
	switch (instr_class(instr)) {
	case INSTR_ARITHMETIC:
		emul_arithmetic(c, instr);
		break;
	case INSTR_BRANCH:
		emul_branch(c, instr);
		break;
	case INSTR_LDR_STR:
		emul_ldr_str(c, instr);
		break;
	default:
		die("invalid instruction class %u (%08x)\n",
		    instr_class(instr), instr);
	}
}

uint32_t cpu_cycle(struct cpu *c)
{
	uint32_t instr;
	int err;

	c->next_pc = c->pc + 4;

	fprintf(c->trace_file, "#%llu\n", c->cycle_count++);
	trace(c->trace_file, TRACE_PC, c->pc);
	err = mem_map_read(c->mem, c->pc, 32, &instr);
	assert(!err);
	trace(c->trace_file, TRACE_INSTR, instr);

	if (instr == SIM_SUCCESS || instr == SIM_FAIL)
		return instr;

	emul_insn(c, instr);

	c->pc = c->next_pc;

	return SIM_CONTINUE;
}
