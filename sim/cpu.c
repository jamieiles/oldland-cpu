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

struct cpu *new_cpu(const char *binary)
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

	err = ram_init(c->mem, 0x20000000, 32 * 1024 * 1024, NULL);
	assert(!err);

	err = sdram_ctrl_init(c->mem, 0x80001000, 4096);
	assert(!err);

	err = debug_uart_init(c->mem, 0x80000000, 0x1000);
	assert(!err);

	return c;
}

static void emul_arithmetic(struct cpu *c, uint32_t instr)
{
	enum regs ra, rb, rd;
	int32_t imm16;
	uint64_t op2;
	uint64_t result = 0;

	ra = instr_ra(instr);
	rb = instr_rb(instr);
	rd = instr_rd(instr);
	imm16 = ((int32_t)instr_imm16(instr) << 16) >> 16;
	op2 = (instr & (1 << 9)) ? c->regs[rb] : imm16;

	switch (instr_opc(instr)) {
	case OPCODE_ADD:
		result = (uint64_t)c->regs[ra] + op2;
		break;
	case OPCODE_ADDC:
		result = (uint64_t)c->regs[ra] + op2 + c->flagsbf.c;
		break;
	case OPCODE_CMP:
		result = (uint64_t)c->regs[ra] - op2;
		break;
	case OPCODE_SUB:
		result = (uint64_t)c->regs[ra] - op2;
		break;
	case OPCODE_SUBC:
		result = (uint64_t)c->regs[ra] - op2 - !c->flagsbf.c;
		break;
	case OPCODE_LSL:
		result = (uint64_t)c->regs[ra] << op2;
		break;
	case OPCODE_ASR:
		result = (uint64_t)(int32_t)c->regs[ra] >> op2;
		break;
	case OPCODE_ORLO:
		result = (uint64_t)c->regs[ra] | (op2 & 0xffff);
		break;
	case OPCODE_LSR:
		result = (uint64_t)c->regs[ra] >> op2;
		break;
	case OPCODE_AND:
		result = (uint64_t)c->regs[ra] & op2;
		break;
	case OPCODE_XOR:
		result = (uint64_t)c->regs[ra] ^ op2;
		break;
	case OPCODE_BIC:
		result = (uint64_t)c->regs[ra] & ~(1 << (op2 % 32));
		break;
	case OPCODE_BST:
		result = (uint64_t)c->regs[ra] | (1 << (op2 % 32));
		break;
	case OPCODE_OR:
		result = (uint64_t)c->regs[ra] | op2;
		break;
	case OPCODE_MOVHI:
		result = op2 << 16;
		break;
	default:
		die("invalid arithmetic opcode %u (%08x)\n", instr_opc(instr),
		    instr);
	}

	if (instr_opc(instr) == OPCODE_CMP) {
		c->flagsbf.z = !result;
		c->flagsbf.c = !!(result & (1LLU << 32));
		trace(c->trace_file, TRACE_FLAGS, c->flagsw);
	}

	if (instr_opc(instr) != OPCODE_CMP)
		cpu_wr_reg(c, rd, result & 0xffffffff);
}

static void emul_branch(struct cpu *c, uint32_t instr)
{
	enum regs rb = instr_rb(instr);
	int32_t imm24 = instr_imm24(instr);
	uint32_t target;

	/* Sign extend the immediate. */
	imm24 <<= 8;
	imm24 >>= 8;

	target = (instr & (1 << 25)) ? rb : c->pc + (imm24 << 2) + 4;

	switch (instr_opc(instr)) {
	case OPCODE_B:
		cpu_set_next_pc(c, target);
		break;
	case OPCODE_BEQ:
		if (c->flagsbf.z)
			cpu_set_next_pc(c, target);
		break;
	case OPCODE_BNE:
		if (!c->flagsbf.z)
			cpu_set_next_pc(c, target);
		break;
	case OPCODE_BGT:
		if (!c->flagsbf.c && !c->flagsbf.z)
			cpu_set_next_pc(c, target);
		break;
	case OPCODE_BLT:
		if (c->flagsbf.c && !c->flagsbf.z)
			cpu_set_next_pc(c, target);
		break;
	case OPCODE_CALL:
		cpu_wr_reg(c, 6, c->pc + 4);
		cpu_set_next_pc(c, target);
		break;
	case OPCODE_RET:
		cpu_set_next_pc(c, c->regs[6]);
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

	/* Sign extend. */
	imm16 <<= 16;
	imm16 >>= 16;

	/* PC relative addressing. */
	if (!(instr & (1 << 9)))
		addr = c->pc + imm16;
	else
		addr = c->regs[ra] + imm16;

	switch (instr_opc(instr)) {
	case OPCODE_LDR8:
		err = mem_map_read(c->mem, addr, 8, &v);
		if (err)
			die("failed to read 8 bits @%08x\n", addr);
		cpu_wr_reg(c, rd, v & 0xff);
		break;
	case OPCODE_LDR16:
		err = mem_map_read(c->mem, addr, 16, &v);
		if (err)
			die("failed to read 16 bits @%08x\n", addr);
		cpu_wr_reg(c, rd, v & 0xffff);
		break;
	case OPCODE_LDR32:
		err = mem_map_read(c->mem, addr, 32, &v);
		if (err)
			die("failed to read 32 bits @%08x\n", addr);
		cpu_wr_reg(c, rd, v);
		break;
	case OPCODE_STR8:
		v = c->regs[rb] & 0xff;
		err = cpu_mem_map_write(c, addr, 8, v);
		if (err)
			die("failed to write 8 bits @%08x\n", addr);
		break;
	case OPCODE_STR16:
		v = c->regs[rb] & 0xffff;
		err = cpu_mem_map_write(c, addr, 16, v);
		if (err)
			die("failed to write 16 bits @%08x\n", addr);
		break;
	case OPCODE_STR32:
		v = c->regs[rb];
		err = cpu_mem_map_write(c, addr, 32, v);
		if (err)
			die("failed to write 32 bits @%08x\n", addr);
		break;
	default:
		die("invalid load/store opcode %u (%08x)\n", instr_opc(instr),
		    instr);
	}
}

static void emul_misc(struct cpu *c, uint32_t instr)
{
	switch (instr_opc(instr)) {
	case OPCODE_NOP:
		break;
	default:
		die("invalid misc opcode %u (%08x)\n", instr_opc(instr),
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
	case INSTR_MISC:
		emul_misc(c, instr);
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
