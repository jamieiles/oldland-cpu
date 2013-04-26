#ifndef __CPU_H__
#define __CPU_H__

#include <lua5.2/lua.h>

struct mem_map;

enum regs {
	R0, R1, R2, R3, R4, R5, FP, SP, PC
};

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
	lua_State *lua_interp;
	FILE *trace_file;
	unsigned long long cycle_count;
};

#endif /* __CPU_H__ */
