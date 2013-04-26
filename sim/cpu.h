#ifndef __CPU_H__
#define __CPU_H__

struct mem_map;

enum regs {
	R0, R1, R2, R3, R4, R5, FP, SP, PC
};

struct cpu;

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

enum sim_status {
	SIM_SUCCESS = 0xffffffff,
	SIM_FAIL = 0xfffffffe,
	SIM_CONTINUE = 0x00000000,
};

struct cpu *new_cpu(const char *test_file, const char *binary);
uint32_t cpu_cycle(struct cpu *c);

#endif /* __CPU_H__ */
