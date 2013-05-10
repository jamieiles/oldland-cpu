#include <assert.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>

#include "cpu.h"
#include "internal.h"
#include "trace.h"

struct {
	int id;
	int width;
	const char *name;
} trace_defs[] = {
	[TRACE_PC]	= { '!', 32, "pc" },
	[TRACE_INSTR]	= { '$', 32, "instr" },
	[TRACE_DADDR]	= { '%', 32, "daddr" },
	[TRACE_DIN]	= { '(', 32, "din" },
	[TRACE_DOUT]	= { ')', 32, "dout" },
	[TRACE_FLAGS]	= { '/', 32, "flags" },
	[TRACE_R0]	= { '0', 32, "R0" },
	[TRACE_R1]	= { '1', 32, "R1" },
	[TRACE_R2]	= { '2', 32, "R2" },
	[TRACE_R3]	= { '3', 32, "R3" },
	[TRACE_R4]	= { '4', 32, "R4" },
	[TRACE_R5]	= { '5', 32, "R5" },
	[TRACE_R6]	= { '6', 32, "R6" },
	[TRACE_R7]	= { '7', 32, "R7" },
};

void trace(FILE *trace_file, enum trace_points tp, uint32_t val)
{
	if (trace_defs[tp].width == 1) {
		fprintf(trace_file, "%d%c\n", !!val, trace_defs[tp].id);
	} else {
		int i;

		fprintf(trace_file, "b");
		for (i = trace_defs[tp].width - 1; i >= 0; --i)
			fprintf(trace_file, "%d", !!(val & (1 << i)));
		fprintf(trace_file, " %c\n", trace_defs[tp].id);
	}
	fflush(trace_file);
}

FILE *init_trace_file(void)
{
	FILE *trace_file;
	int i;

	trace_file = fopen("oldland.vcd", "w");
	assert(trace_file);
	fprintf(trace_file, "$timescale 1ns $end\n");
	fprintf(trace_file, "$scope module cpu $end\n");
	for (i = 0; i < ARRAY_SIZE(trace_defs); ++i)
		fprintf(trace_file, "$var wire %u %c %s $end\n",
			trace_defs[i].width, trace_defs[i].id,
			trace_defs[i].name);
	fprintf(trace_file, "$upscope $end\n");
	fprintf(trace_file, "$enddefinitions $end\n");
	fprintf(trace_file, "$dumpvars\n");
	for (i = 0; i < ARRAY_SIZE(trace_defs); ++i)
		trace(trace_file, i, 0);

	return trace_file;
}
