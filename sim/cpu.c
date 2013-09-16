#define _GNU_SOURCE
#include <assert.h>
#include <err.h>
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

#ifndef ROM_FILE
#define ROM_FILE NULL
#endif

enum instruction_class {
	INSTR_ARITHMETIC,
	INSTR_BRANCH,
	INSTR_LDR_STR,
	INSTR_MISC,
};

enum exception_vector {
	VECTOR_RESET		= 0x00,
	VECTOR_ILLEGAL_INSTR	= 0x04,
	VECTOR_SWI		= 0x08,
	VECTOR_IRQ		= 0x0c,
	VECTOR_IFETCH_ABORT	= 0x10,
	VECTOR_DATA_ABORT	= 0x14,
};

enum control_register {
	CR_VECTOR_ADDRESS	= 0,
	CR_PSR			= 1,
	CR_SAVED_PSR		= 2,
	CR_FAULT_ADDRESS	= 3,
	CR_DATA_FAULT_ADDRESS	= 4,
	NUM_CONTROL_REGS
};

struct cpu {
	uint32_t pc;
	uint32_t next_pc;
	uint32_t regs[16];
	union {
		uint32_t flagsw;
		struct {
			unsigned n:1;
			unsigned o:1;
			unsigned z:1;
			unsigned c:1;
		} flagsbf;
	};

	struct mem_map *mem;
	FILE *trace_file;
	unsigned long long cycle_count;
        uint32_t control_regs[NUM_CONTROL_REGS];
};

int cpu_read_reg(const struct cpu *c, unsigned regnum, uint32_t *v)
{
	if (regnum >= 17)
		return -1;
	if (regnum == 16)
		*v = c->pc;
	else
		*v = c->regs[regnum];

	return 0;
}

int cpu_write_reg(struct cpu *c, unsigned regnum, uint32_t v)
{
	if (regnum >= 17)
		return -1;
	if (regnum == 16)
		c->pc = v;
	else
		c->regs[regnum] = v;

	return 0;
}

int cpu_read_mem(struct cpu *c, uint32_t addr, uint32_t *v, size_t nbits)
{
	return mem_map_read(c->mem, addr, nbits, v);
}

int cpu_write_mem(struct cpu *c, uint32_t addr, uint32_t v, size_t nbits)
{
	return mem_map_write(c->mem, addr, nbits, v);
}

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
	return (instr >> 0) & 0xf;
}

static inline enum regs instr_ra(uint32_t instr)
{
	return (instr >> 8) & 0xf;
}

static inline enum regs instr_rb(uint32_t instr)
{
	return (instr >> 4) & 0xf;
}

static inline uint16_t instr_imm16(uint32_t instr)
{
	return (instr >> 10) & 0xffff;
}

static inline uint16_t instr_imm13(uint32_t instr)
{
	return (instr >> 12) & 0x1fff;
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

struct cpu *new_cpu(const char *binary, int flags)
{
	int err;
	struct cpu *c;

	c = calloc(1, sizeof(*c));
	assert(c);

	if (!(flags & CPU_NOTRACE))
		c->trace_file = init_trace_file();

	c->mem = mem_map_new();
	assert(c->mem);

	err = ram_init(c->mem, 0x00000000, 0x10000, binary);
	assert(!err);

	err = rom_init(c->mem, 0x10000000, 0x1000, ROM_FILE);
	assert(!err);

	err = ram_init(c->mem, 0x20000000, 32 * 1024 * 1024, NULL);
	assert(!err);

	err = sdram_ctrl_init(c->mem, 0x80001000, 4096);
	assert(!err);

	err = debug_uart_init(c->mem, 0x80000000, 0x1000);
	assert(!err);

	return c;
}

static uint32_t current_psr(const struct cpu *c)
{
	return c->flagsbf.z | (c->flagsbf.c << 1) | (c->flagsbf.o << 2);
}

enum psr_flags {
	PSR_Z	= (1 << 0),
	PSR_C	= (1 << 1),
	PSR_I	= (1 << 2),
	PSR_U	= (1 << 3),
};

static void set_psr(struct cpu *c, uint32_t psr)
{
	c->flagsw = psr & (PSR_C | PSR_Z);
}

static void do_vector(struct cpu *c, enum exception_vector vector)
{
	c->control_regs[CR_SAVED_PSR] = current_psr(c);
	c->control_regs[CR_FAULT_ADDRESS] = c->pc + 4;
	cpu_set_next_pc(c, c->control_regs[CR_VECTOR_ADDRESS] | vector);
}

static void emul_arithmetic(struct cpu *c, uint32_t instr)
{
	enum regs ra, rb, rd;
	int32_t imm13;
	uint64_t op2;
	uint64_t result = 0;
	bool upc = false, upz = false, upo = false, upn = false;

	ra = instr_ra(instr);
	rb = instr_rb(instr);
	rd = instr_rd(instr);
	imm13 = ((int32_t)instr_imm13(instr) << 19) >> 19;
	op2 = (instr & (1 << 25)) ? c->regs[rb] : imm13;

	switch (instr_opc(instr)) {
	case OPCODE_ADD:
		upc = true;
		result = (uint64_t)c->regs[ra] + op2;
		break;
	case OPCODE_ADDC:
		upc = true;
		op2 += c->flagsbf.c;
		result = (uint64_t)c->regs[ra] + op2;
		break;
	case OPCODE_CMP:
		upc = upz = upo = upn = true;
		result = (uint64_t)c->regs[ra] - op2;
		break;
	case OPCODE_SUB:
		upc = true;
		result = (uint64_t)c->regs[ra] - op2;
		break;
	case OPCODE_SUBC:
		upc = true;
		op2 -= c->flagsbf.c;
		result = (uint64_t)c->regs[ra] - op2;
		break;
	case OPCODE_LSL:
		result = (uint64_t)c->regs[ra] << op2;
		break;
	case OPCODE_ASR:
		result = (uint64_t)(int32_t)c->regs[ra] >> op2;
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
	default:
		do_vector(c, VECTOR_ILLEGAL_INSTR);
		return;
	}

	if (upc || upz || upo || upn) {
		if (upz)
			c->flagsbf.z = !result;
		if (upc)
			c->flagsbf.c = !!(result & (1LLU << 32));
		if (upo)
			c->flagsbf.o = (c->regs[ra] & 0x80000000) ^ (op2 & 0x80000000) &&
				(result & 0x80000000) == (op2 & 0x80000000);
		if (upn)
			c->flagsbf.n = !!(result & 0x80000000);
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

	target = (instr & (1 << 25)) ? c->regs[rb] : c->pc + (imm24 << 2) + 4;

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
	case OPCODE_BGTS:
		if (!c->flagsbf.z && (c->flagsbf.n == c->flagsbf.o))
			cpu_set_next_pc(c, target);
		break;
	case OPCODE_BLT:
		if (c->flagsbf.c && !c->flagsbf.z)
			cpu_set_next_pc(c, target);
		break;
	case OPCODE_BLTS:
		if (c->flagsbf.n != c->flagsbf.o)
			cpu_set_next_pc(c, target);
		break;
	case OPCODE_CALL:
		cpu_wr_reg(c, 0xf, c->pc + 4);
		cpu_set_next_pc(c, target);
		break;
	case OPCODE_RET:
		cpu_set_next_pc(c, c->regs[LR]);
		break;
	case OPCODE_SWI:
		do_vector(c, VECTOR_SWI);
		break;
	case OPCODE_RFE:
		cpu_set_next_pc(c, c->control_regs[CR_FAULT_ADDRESS]);
		set_psr(c, c->control_regs[CR_SAVED_PSR]);
		break;
	default:
		do_vector(c, VECTOR_ILLEGAL_INSTR);
	}
}

static int cpu_mem_map_write(struct cpu *c, physaddr_t addr,
			     unsigned int nr_bits, uint32_t val)
{
	trace(c->trace_file, TRACE_DADDR, addr);
	trace(c->trace_file, TRACE_DOUT, val);

	return mem_map_write(c->mem, addr, nr_bits, val);
}

static void emul_ldr_str(struct cpu *c, uint32_t instr)
{
	int32_t imm13 = instr_imm13(instr);
	uint32_t addr, v = 0;
	enum regs ra = instr_ra(instr), rb = instr_rb(instr), rd = instr_rd(instr);
	int err = 0;

	/* Sign extend. */
	imm13 <<= 19;
	imm13 >>= 19;

	/* PC relative addressing. */
	if (!(instr & (1 << 25)))
		addr = c->pc + 4 + imm13;
	else
		addr = c->regs[ra] + imm13;

	switch (instr_opc(instr)) {
	case OPCODE_LDR8:
		err = mem_map_read(c->mem, addr, 8, &v);
		if (!err)
			cpu_wr_reg(c, rd, v & 0xff);
		break;
	case OPCODE_LDR16:
		err = mem_map_read(c->mem, addr, 16, &v);
		if (!err)
			cpu_wr_reg(c, rd, v & 0xffff);
		break;
	case OPCODE_LDR32:
		err = mem_map_read(c->mem, addr, 32, &v);
		if (!err)
			cpu_wr_reg(c, rd, v);
		break;
	case OPCODE_STR8:
		v = c->regs[rb] & 0xff;
		err = cpu_mem_map_write(c, addr, 8, v);
		break;
	case OPCODE_STR16:
		v = c->regs[rb] & 0xffff;
		err = cpu_mem_map_write(c, addr, 16, v);
		break;
	case OPCODE_STR32:
		v = c->regs[rb];
		err = cpu_mem_map_write(c, addr, 32, v);
		break;
	default:
		do_vector(c, VECTOR_ILLEGAL_INSTR);
	}

	if (err) {
		c->control_regs[CR_DATA_FAULT_ADDRESS] = addr;
		do_vector(c, VECTOR_DATA_ABORT);
	}
}

static void emul_misc(struct cpu *c, uint32_t instr)
{
	int32_t imm16 = (int32_t)instr_imm16(instr);
	int32_t imm13 = (int32_t)instr_imm13(instr);
	uint64_t result;
	enum regs ra = instr_ra(instr);
	enum regs rb = instr_rb(instr);
	enum regs rd = instr_rd(instr);

	switch (instr_opc(instr)) {
	case OPCODE_NOP:
		break;
	case OPCODE_ORLO:
		result = (uint64_t)c->regs[rb] | imm16;
		cpu_wr_reg(c, rd, result & 0xffffffff);
		break;
	case OPCODE_MOVHI:
		result = imm16 << 16;
		cpu_wr_reg(c, rd, result & 0xffffffff);
		break;
        case OPCODE_SCR:
                if (imm13 < NUM_CONTROL_REGS)
                        c->control_regs[imm13] = c->regs[ra];
                break;
        case OPCODE_GCR:
                if (imm13 < NUM_CONTROL_REGS)
                        cpu_wr_reg(c, rd, c->control_regs[imm13]);
                break;
	default:
		do_vector(c, VECTOR_ILLEGAL_INSTR);
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
		do_vector(c, VECTOR_ILLEGAL_INSTR);
	}
}

int cpu_cycle(struct cpu *c)
{
	uint32_t instr;

	c->next_pc = c->pc + 4;

	if (c->trace_file)
		fprintf(c->trace_file, "#%llu\n", c->cycle_count++);
	trace(c->trace_file, TRACE_PC, c->pc);
	if (mem_map_read(c->mem, c->pc, 32, &instr)) {
		do_vector(c, VECTOR_IFETCH_ABORT);
		goto out;
	}
	if (c->trace_file)
		trace(c->trace_file, TRACE_INSTR, instr);

	emul_insn(c, instr);

out:
	c->pc = c->next_pc;

	return 0;
}

void cpu_reset(struct cpu *c)
{
	int r;

	c->pc = c->next_pc = 0;
	for (r = 0; r <= LR; ++r)
		c->regs[r] = 0;
	c->flagsw = 0;
	c->cycle_count = 0;

	for (r = 0; r < NUM_CONTROL_REGS; ++r)
		c->control_regs[r] = 0;
}
