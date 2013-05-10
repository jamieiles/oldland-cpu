#ifndef __CPU_H__
#define __CPU_H__

#include <stdio.h>

struct mem_map;

enum regs {
	R0, R1, R2, R3, R4, R5, FP, SP, PC
};

enum sim_status {
	SIM_SUCCESS = 0xffffffff,
	SIM_FAIL = 0xfffffffe,
	SIM_CONTINUE = 0x00000000,
};

struct cpu *new_cpu(const char *binary);
uint32_t cpu_cycle(struct cpu *c);

#endif /* __CPU_H__ */
