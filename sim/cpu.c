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

#include "cache.h"
#include "cpu.h"
#include "internal.h"
#include "irq_ctrl.h"
#include "io.h"
#include "microcode.h"
#include "trace.h"
#include "oldland-types.h"
#include "periodic.h"
#include "sdcard.h"
#include "spimaster.h"

#ifndef ROM_FILE
#define ROM_FILE NULL
#endif

#ifndef MICROCODE_FILE
#define MICROCODE_FILE NULL
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

#define MICROCODE_NR_WORDS	(1 << 7)

struct cpu {
	uint32_t pc;
	uint32_t next_pc;
	uint32_t regs[16];
	union {
		uint32_t flagsw;
		struct {
			unsigned ic:1;
			unsigned dc:1;
			unsigned i:1;
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
	uint32_t ucode[MICROCODE_NR_WORDS];
	bool irq_active;
	struct event_list events;
	struct irq_ctrl *irq_ctrl;
	struct timer_base *timers;
        struct spimaster *spimaster;
	struct cache *icache;
	struct cache *dcache;
};

enum cpuid_reg_names {
	CPUID_VERSION,
	CPUID_CORE_SPEED,
	CPUID_FEATURES,
	CPUID_ICACHE,
	CPUID_DCACHE,
};

#define CPUID_ICACHE_VAL	((ICACHE_LINE_SIZE / sizeof(uint32_t)) | \
				  ((1 << ICACHE_INDEX_BITS) << 8) | \
                                 (ICACHE_NUM_WAYS << 24))
#define CPUID_DCACHE_VAL	((DCACHE_LINE_SIZE / sizeof(uint32_t)) | \
				  ((1 << DCACHE_INDEX_BITS) << 8) | \
                                 (DCACHE_NUM_WAYS << 24))

static const uint32_t cpuid_regs[] = {
	[CPUID_VERSION]		= (CPUID_MANUFACTURER << 16) | CPUID_MODEL,
	[CPUID_CORE_SPEED]	= CPU_CLOCK_SPEED,
	[CPUID_FEATURES]	= 0,
	[CPUID_ICACHE]		= CPUID_ICACHE_VAL,
	[CPUID_DCACHE]		= CPUID_DCACHE_VAL,
};

enum psr_flags {
	PSR_Z	= (1 << 0),
	PSR_C	= (1 << 1),
	PSR_O	= (1 << 2),
	PSR_N	= (1 << 3),
	PSR_I	= (1 << 4),
	PSR_DC	= (1 << 5),
	PSR_IC	= (1 << 6),
};

static inline int data_cache_enabled(const struct cpu *c)
{
	return c->flagsbf.dc;
}

static inline int instruction_cache_enabled(const struct cpu *c)
{
	return c->flagsbf.ic;
}

static void set_psr(struct cpu *c, uint32_t psr)
{
	c->flagsbf.i = !!(psr & PSR_I);
	c->flagsbf.n = !!(psr & PSR_N);
	c->flagsbf.o = !!(psr & PSR_O);
	c->flagsbf.c = !!(psr & PSR_C);
	c->flagsbf.z = !!(psr & PSR_Z);
	c->flagsbf.dc = !!(psr & PSR_DC);
	c->flagsbf.ic = !!(psr & PSR_IC);
}

static uint32_t current_psr(const struct cpu *c)
{
	return c->flagsbf.z | (c->flagsbf.c << 1) | (c->flagsbf.o << 2) |
		(c->flagsbf.n << 3) | (c->flagsbf.i << 4) |
		(c->flagsbf.dc << 5) | (c->flagsbf.ic << 6);
}

int cpu_read_reg(struct cpu *c, unsigned regnum, uint32_t *v)
{
	c->control_regs[CR_PSR] = current_psr(c);

	if ((regnum > PC && regnum < CR_BASE) ||
	    regnum >= CR_BASE + NUM_CONTROL_REGS)
		return -1;
	if (regnum == 16)
		*v = c->pc;
	else if (regnum >= CR_BASE)
		*v = c->control_regs[regnum - CR_BASE];
	else
		*v = c->regs[regnum];

	return 0;
}

int cpu_write_reg(struct cpu *c, unsigned regnum, uint32_t v)
{
	if ((regnum > PC && regnum < CR_BASE) ||
	    regnum >= CR_BASE + NUM_CONTROL_REGS)
		return -1;
	if (regnum == 16)
		c->pc = v;
	else if (regnum >= CR_BASE)
		c->control_regs[regnum - CR_BASE] = v;
	else
		c->regs[regnum] = v;

	if (regnum == CR_BASE + CR_PSR)
		set_psr(c, c->control_regs[CR_PSR]);

	return 0;
}

int cpu_read_mem(struct cpu *c, uint32_t addr, uint32_t *v, size_t nbits)
{
	if (mem_map_addr_cacheable(c->mem, addr) &&
	    data_cache_enabled(c))
		return cache_read(c->dcache, addr, nbits, v);

	return mem_map_read(c->mem, addr, nbits, v);
}

int cpu_write_mem(struct cpu *c, uint32_t addr, uint32_t v, size_t nbits)
{
	if (mem_map_addr_cacheable(c->mem, addr) &&
	    data_cache_enabled(c))
		return cache_write(c->dcache, addr, nbits, v);

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

static int load_microcode(struct cpu *c, const char *path)
{
	FILE *fp = fopen(path, "r");
	unsigned m = 0;

	if (!fp)
		return -1;

	while (!feof(fp)) {
		/* microcode lines should be 8 hex chars + newline. */
		char buf[16];
		char *end;
		uint32_t v;

		if (!fgets(buf, sizeof(buf), fp))
			break;

		v = strtoul(buf, &end, 16);
		if (end == buf)
			continue;

		if (m == MICROCODE_NR_WORDS)
			errx(1, "malformed microcode file, too many words");

		c->ucode[m++] = v;
	}

	fclose(fp);

	return 0;
}

static void cpu_raise_irq(void *data)
{
	struct cpu *c = data;

	c->irq_active = true;
}

static void cpu_clear_irq(void *data)
{
	struct cpu *c = data;

	c->irq_active = false;
}

struct cpu *new_cpu(const char *binary, int flags,
		    const char *bootrom_image,
		    const char *sdcard_image)
{
	int err;
	struct cpu *c;
	struct timer_init_data timer_data;
	struct spislave **spislaves;

	c = calloc(1, sizeof(*c));
	assert(c);

	if (!(flags & CPU_NOTRACE))
		c->trace_file = init_trace_file();

	event_list_init(&c->events);

	c->mem = mem_map_new();
	assert(c->mem);

	err = ram_init(c->mem, RAM_ADDRESS, RAM_SIZE, binary);
	assert(!err);

	err = rom_init(c->mem, BOOTROM_ADDRESS, BOOTROM_SIZE, bootrom_image);
	assert(!err);

	err = ram_init(c->mem, SDRAM_ADDRESS, SDRAM_SIZE, NULL);
	assert(!err);

	err = sdram_ctrl_init(c->mem, SDRAM_CTRL_ADDRESS, SDRAM_CTRL_SIZE);
	assert(!err);

	err = debug_uart_init(c->mem, UART_ADDRESS, UART_SIZE);
	assert(!err);

	c->irq_ctrl = irq_ctrl_init(c->mem, IRQ_ADDRESS, cpu_raise_irq,
				    cpu_clear_irq, c);
	assert(c->irq_ctrl != NULL);

	timer_data = (struct timer_init_data) {
		.irq_ctrl = c->irq_ctrl,
		.irqs = { 0, 1, 2, 3 },
	};
	c->timers = timers_init(c->mem, TIMER_ADDRESS, &c->events, &timer_data);
	assert(c->timers);

	spislaves = calloc(1, sizeof(*spislaves));
	assert(spislaves != NULL);
	if (sdcard_image)
		spislaves[0] = sdcard_new(sdcard_image);
	c->spimaster = spimaster_init(c->mem, SPIMASTER_ADDRESS, spislaves,
				      ARRAY_SIZE(spislaves));
        assert(c->spimaster);

	c->icache = cache_new(c->mem);
	assert(c->icache);

	c->dcache = cache_new(c->mem);
	assert(c->dcache);

	err = load_microcode(c, MICROCODE_FILE);
	assert(!err);

	cpu_reset(c);

	return c;
}

static void do_vector(struct cpu *c, enum exception_vector vector)
{
	c->control_regs[CR_SAVED_PSR] = current_psr(c);
	c->control_regs[CR_FAULT_ADDRESS] = c->irq_active ? c->pc : c->pc + 4;
	/* Exception handlers run with interrupts disabled. */
	c->flagsbf.i = 0;
	cpu_set_next_pc(c, c->control_regs[CR_VECTOR_ADDRESS] | vector);
}

static int cpu_mem_map_write(struct cpu *c, physaddr_t addr,
			     unsigned int nr_bits, uint32_t val)
{
	trace(c->trace_file, TRACE_DADDR, addr);
	trace(c->trace_file, TRACE_DOUT, val);

	return cpu_write_mem(c, addr, val, nr_bits);
}

static uint32_t fetch_op1(struct cpu *c, uint32_t instr, uint32_t ucode)
{
	if (ucode_op1ra(ucode))
		return c->regs[instr_ra(instr)];
	else if (ucode_op1rb(ucode))
		return c->regs[instr_rb(instr)];
	else
		return c->pc + 4;
}

static uint32_t fetch_op2(struct cpu *c, uint32_t instr, uint32_t ucode)
{
	if (ucode_op2rb(ucode))
		return c->regs[instr_rb(instr)];

	switch (ucode_imsel(ucode)) {
	case IMSEL_IMM13:
		return ((int32_t)instr_imm13(instr) << 19) >> 19;
	case IMSEL_IMM24:
		return ((int32_t)(instr_imm24(instr) << 2) << 8) >> 8;
	case IMSEL_HI16:
		return instr_imm16(instr) << 16;
	case IMSEL_LO16:
		return instr_imm16(instr);
	default:
		errx(1, "invalid immediate select");
	}
}

enum branch_condition {
	BRANCH_CC_NE	= 0x1,
	BRANCH_CC_EQ	= 0x2,
	BRANCH_CC_GT	= 0x3,
	BRANCH_CC_LT	= 0x4,
	BRANCH_CC_GTS	= 0x5,
	BRANCH_CC_LTS	= 0x6,
	BRANCH_CC_B	= 0x7,
	BRANCH_CC_GTE	= 0x8,
	BRANCH_CC_GTES  = 0x9,
	BRANCH_CC_LTE   = 0xa,
	BRANCH_CC_LTES  = 0xb,
};

static bool branch_condition_met(const struct cpu *c, enum branch_condition cond)
{
	switch (cond) {
	case BRANCH_CC_NE:
		return !c->flagsbf.z;
	case BRANCH_CC_EQ:
		return c->flagsbf.z;
	case BRANCH_CC_GT:
		return c->flagsbf.c && !c->flagsbf.z;
	case BRANCH_CC_LT:
		return !c->flagsbf.c;
	case BRANCH_CC_GTS:
		return !c->flagsbf.z && (c->flagsbf.n == c->flagsbf.o);
	case BRANCH_CC_LTS:
		return c->flagsbf.n != c->flagsbf.o;
	case BRANCH_CC_B:
		return true;
	case BRANCH_CC_GTE:
		return c->flagsbf.c;
	case BRANCH_CC_GTES:
		return c->flagsbf.n == c->flagsbf.o;
	case BRANCH_CC_LTE:
		return !c->flagsbf.c || c->flagsbf.z;
	case BRANCH_CC_LTES:
		return (c->flagsbf.n != c->flagsbf.o) || c->flagsbf.z;
	default:
		return false;
	}
}

struct alu_result {
	uint32_t alu_q;
	int alu_c;
	int alu_o;
	int alu_n;
	int alu_z;
	uint32_t mem_write_val;
};

static void do_alu(struct cpu *c, uint32_t instr, uint32_t ucode,
		   struct alu_result *alu)
{
	uint64_t op1 = fetch_op1(c, instr, ucode);
	uint64_t op2 = fetch_op2(c, instr, ucode);
	uint64_t v;

	alu->alu_z = !(op1 ^ op2);

	switch (ucode_aluop(ucode)) {
	case ALU_OPCODE_ADD:
		v = op1 + op2;
		alu->alu_q = v;
		alu->alu_c = (v >> 32) & 0x1;
		break;
	case ALU_OPCODE_MUL:
		v = op1 * op2;
		alu->alu_q = v;
		alu->alu_c = (v >> 32) & 0x1;
		break;
	case ALU_OPCODE_ADDC:
		v = op1 + op2 + c->flagsbf.c;
		alu->alu_q = v;
		alu->alu_c = (v >> 32) & 0x1;
		break;
	case ALU_OPCODE_SUB:
		v = op1 - op2;
		alu->alu_q = v;
		alu->alu_c = (v >> 32) & 0x1;
		break;
	case ALU_OPCODE_SUBC:
		v = op1 - op2 - c->flagsbf.c;
		alu->alu_q = v;
		alu->alu_c = (v >> 32) & 0x1;
		break;
	case ALU_OPCODE_LSL:
		v = op1 << (op2 & 0x1f);
		alu->alu_q = v;
		alu->alu_c = (v >> 32) & 0x1;
		break;
	case ALU_OPCODE_LSR:
		alu->alu_q = op1 >> (op2 & 0x1f);
		break;
	case ALU_OPCODE_AND:
		alu->alu_q = op1 & op2;
		break;
	case ALU_OPCODE_XOR:
		alu->alu_q = op1 ^ op2;
		break;
	case ALU_OPCODE_BIC:
		alu->alu_q = op1 & ~(1 << (op2 & 0x1f));
		break;
	case ALU_OPCODE_BST:
		alu->alu_q = op1 | (1 << (op2 & 0x1f));
		break;
	case ALU_OPCODE_OR:
		alu->alu_q = op1 | op2;
		break;
	case ALU_OPCODE_COPYB:
		alu->alu_q = op2;
		break;
	case ALU_OPCODE_CMP:
		v = op1 - op2;
		alu->alu_q = v;
		alu->alu_c = !((v >> 32) & 0x1);
		alu->alu_o = (op1 & (1 << 31)) ^ (op2 & (1 << 31)) &&
			(alu->alu_q & (1 << 31)) == (op2 & (1 << 31));
		alu->alu_n = !!(alu->alu_q & (1 << 31));
		break;
	case ALU_OPCODE_MOVHI:
		alu->alu_q = op1 | (op2 & 0xffff);
		break;
	case ALU_OPCODE_ASR:
		alu->alu_q = ((int64_t)op1 << 32) >> 32;
		alu->alu_q = (int32_t)alu->alu_q >> op2;
		break;
	case ALU_OPCODE_GCR:
		c->control_regs[CR_PSR] = (
			c->flagsbf.z << 0 |
			c->flagsbf.c << 1 |
			c->flagsbf.o << 2 |
			c->flagsbf.n << 3 |
			c->flagsbf.i << 4 |
			c->flagsbf.dc << 5 |
			c->flagsbf.ic << 6);
		alu->alu_q = op2 < NUM_CONTROL_REGS ? c->control_regs[op2] : 0;
		break;
	case ALU_OPCODE_SWI:
		alu->alu_q = c->control_regs[CR_VECTOR_ADDRESS] | 0x8;
		break;
	case ALU_OPCODE_RFE:
		alu->alu_q = c->control_regs[CR_FAULT_ADDRESS];
		break;
	case ALU_OPCODE_COPYA:
		alu->alu_q = op1;
		break;
	case ALU_OPCODE_CPUID:
		if (op2 >= ARRAY_SIZE(cpuid_regs))
			alu->alu_q = 0;
		else
			alu->alu_q = cpuid_regs[op2];
		break;
	}

	alu->mem_write_val = c->regs[instr_rb(instr)];
}

static bool branch_taken(const struct cpu *c, uint32_t instr, uint32_t ucode)
{
	if (instr_class(instr) != INSTR_BRANCH)
		return false;

	return branch_condition_met(c, ucode_bcc(ucode)) ||
		 ucode_swi(ucode) || ucode_rfe(ucode);
}

static void commit_alu(struct cpu *c, uint32_t instr, uint32_t ucode,
		       const struct alu_result *alu)
{
	if (ucode_upc(ucode))
		c->flagsbf.c = alu->alu_c;

	if (ucode_upcc(ucode)) {
		c->flagsbf.o = alu->alu_o;
		c->flagsbf.n = alu->alu_n;
		c->flagsbf.z = alu->alu_z;
	}

	if (ucode_wrrd(ucode)) {
		int rd = ucode_rdlr(ucode) ? LR : instr_rd(instr);
		uint32_t v = ucode_icall(ucode) ? c->pc + 4 : alu->alu_q;

		cpu_wr_reg(c, rd, v);
	}
}

static void process_branch(struct cpu *c, uint32_t instr, uint32_t ucode,
			   const struct alu_result *alu)
{
	if (branch_taken(c, instr, ucode))
		cpu_set_next_pc(c, alu->alu_q);

	if (ucode_rfe(ucode))
		set_psr(c, c->control_regs[CR_SAVED_PSR]);

	if (ucode_swi(ucode)) {
		c->control_regs[CR_SAVED_PSR] = current_psr(c);
		c->control_regs[CR_FAULT_ADDRESS] = c->pc + 4;
		c->flagsbf.i = 0;
	}
}

static void do_scr(struct cpu *c, uint32_t instr, uint32_t ucode,
		   const struct alu_result *alu)
{
	unsigned cr_sel = (instr >> 12) & 0x7;

	if (!ucode_wcr(ucode))
		return;

	if (cr_sel >= NUM_CONTROL_REGS)
		return;

	c->control_regs[cr_sel] = alu->alu_q;
	if (cr_sel == CR_PSR)
		set_psr(c, c->control_regs[CR_PSR]);
}

static unsigned maw_to_bits(enum maw maw)
{
	switch (maw) {
	case MAW_8:
		return 8;
	case MAW_16:
		return 16;
	case MAW_32:
		return 32;
	default:
		errx(1, "invalid memory access width");
	}
}

static int do_memory(struct cpu *c, uint32_t instr, uint32_t ucode,
		     const struct alu_result *alu)
{
	uint32_t v, addr = alu->alu_q;
	int err = 0;

	if (!ucode_mstr(ucode) && !ucode_mldr(ucode) && !ucode_cache(ucode))
		return 0;

	if (ucode_mstr(ucode)) {
		err = cpu_mem_map_write(c, alu->alu_q,
					maw_to_bits(ucode_maw(ucode)),
					alu->mem_write_val);
	} else if (ucode_mldr(ucode)) {
		err = cpu_read_mem(c, alu->alu_q,
				   &v, maw_to_bits(ucode_maw(ucode)));
		if (!err)
			cpu_wr_reg(c, instr_rd(instr), v);
	} else if (ucode_cache(ucode)) {
		uint32_t op2 = fetch_op2(c, instr, ucode);

		switch (op2) {
		case 0x0:
			cache_inval_index(c->icache, alu->alu_q);
			break;
		case 0x1:
			cache_inval_index(c->dcache, alu->alu_q);
			break;
		case 0x2:
			cache_flush_index(c->dcache, alu->alu_q);
			break;
		}
	}

	if (err) {
		c->control_regs[CR_DATA_FAULT_ADDRESS] = addr;
		do_vector(c, VECTOR_DATA_ABORT);
	}

	return err;
}

static bool instr_is_breakpoint(uint32_t instr)
{
	if (instr_class(instr) != INSTR_MISC || instr_opc(instr) != OPCODE_BKP)
		return false;

	return true;
}

static void emul_insn(struct cpu *c, uint32_t instr, bool *breakpoint_hit)
{
	/* 7 MSB's are the microcode address. */
	uint32_t ucode = c->ucode[instr >> (32 - 7)];
	struct alu_result alu = {};

	if (c->irq_active && c->flagsbf.i) {
		do_vector(c, VECTOR_IRQ);
		return;
	}

	if (!ucode_valid(ucode)) {
		do_vector(c, VECTOR_ILLEGAL_INSTR);
		return;
	}

	if (instr_is_breakpoint(instr))
		*breakpoint_hit = true;

	do_alu(c, instr, ucode, &alu);
	commit_alu(c, instr, ucode, &alu);
	process_branch(c, instr, ucode, &alu);
	do_scr(c, instr, ucode, &alu);

	if (do_memory(c, instr, ucode, &alu))
		return;
}

static int instruction_read(struct cpu *c, uint32_t *instr)
{
	if (instruction_cache_enabled(c))
		return cache_read(c->icache, c->pc, 32, instr);
	return mem_map_read(c->mem, c->pc, 32, instr);
}

int cpu_cycle(struct cpu *c, bool *breakpoint_hit)
{
	uint32_t instr;

	event_list_tick(&c->events);

	c->next_pc = c->pc + 4;

	if (c->trace_file)
		fprintf(c->trace_file, "#%llu\n", c->cycle_count++);
	trace(c->trace_file, TRACE_PC, c->pc);
	if (instruction_read(c, &instr)) {
		do_vector(c, VECTOR_IFETCH_ABORT);
		goto out;
	}
	if (c->trace_file)
		trace(c->trace_file, TRACE_INSTR, instr);

	emul_insn(c, instr, breakpoint_hit);

out:
	if (!*breakpoint_hit)
		c->pc = c->next_pc;

	return 0;
}

void cpu_cache_sync(struct cpu *cpu)
{
	cache_flush_all(cpu->dcache);
	cache_inval_all(cpu->icache);
}

uint32_t cpu_cpuid(unsigned int reg)
{
	if (reg >= ARRAY_SIZE(cpuid_regs))
		return 0;

	return cpuid_regs[reg];
}

void cpu_reset(struct cpu *c)
{
	int r;

	c->pc = c->next_pc = BOOTROM_ADDRESS;
	for (r = 0; r <= LR; ++r)
		c->regs[r] = 0;
	c->flagsw = 0;
	c->cycle_count = 0;

	for (r = 0; r < NUM_CONTROL_REGS; ++r)
		c->control_regs[r] = 0;
	c->irq_active = false;
	irq_ctrl_reset(c->irq_ctrl);
	timers_reset(c->timers);
	cache_inval_all(c->icache);
	cache_inval_all(c->dcache);
}
