/*
 * Runs with the instruction cache enabled.
 *
 * This should read all instructions up to SUCCESS into a single cache line.
 * We then patch one of the nops with an infinite loop.  If we're running
 * cached instructions we'll see the nop and continue to SUCCESS rather than
 * getting stuck in the loop.
 */
.include "common.s"

.globl _start
_start:
	ldr32	$r0, loop
	str32	$r0, target
	nop
	nop
	nop
target:
	nop
	nop
	nop
	SUCCESS

loop:
	b	loop

success:
	SUCCESS
