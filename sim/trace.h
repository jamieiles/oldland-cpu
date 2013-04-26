#ifndef __TRACE_H__
#define __TRACE_H__

#include <stdint.h>

#include "cpu.h"

enum trace_points {
	TRACE_PC,
	TRACE_INSTR,
	TRACE_R0,
	TRACE_R1,
	TRACE_R2,
	TRACE_R3,
	TRACE_R4,
	TRACE_R5,
	TRACE_R6,
	TRACE_R7,
	TRACE_DADDR,
	TRACE_DIN,
	TRACE_DOUT,
	TRACE_FLAGS,
};

void trace(struct cpu *c, enum trace_points tp, uint32_t val);
void init_trace_file(struct cpu *c);

#endif /* __TRACE_H__ */
