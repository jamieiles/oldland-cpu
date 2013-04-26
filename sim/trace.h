#ifndef __TRACE_H__
#define __TRACE_H__

#include <stdint.h>

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

void trace(FILE *trace_file, enum trace_points tp, uint32_t val);
FILE *init_trace_file(void);

#endif /* __TRACE_H__ */
