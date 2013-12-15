#ifndef __CPU_H__
#define __CPU_H__

#include <stdbool.h>
#include <stdio.h>
#include <stdint.h>

struct mem_map;

enum regs {
	R0, R1, R2, R3, R4, R5, R6, R7, R8, R9, R10, R11, R12, FP, SP, LR, PC,
	CR_BASE = 32
};

enum cpu_flags {
	CPU_NOTRACE = 1 << 0,
};

struct cpu *new_cpu(const char *binary, int flags);
int cpu_cycle(struct cpu *c, bool *breakpoint_hit);
int cpu_read_reg(struct cpu *c, unsigned regnum, uint32_t *v);
int cpu_write_reg(struct cpu *c, unsigned regnum, uint32_t v);
int cpu_read_mem(struct cpu *c, uint32_t addr, uint32_t *v, size_t nbits);
int cpu_write_mem(struct cpu *c, uint32_t addr, uint32_t v, size_t nbits);
void cpu_reset(struct cpu *c);
void cpu_cache_sync(struct cpu *cpu);
uint32_t cpu_cpuid(unsigned int reg);

#endif /* __CPU_H__ */
