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
	TESTPOINT	TP_USER, 0
	/*
	 * Branch to a word at the end of a cache line, to make sure that our
	 * line fills handle that case correctly and we don't return incorrect
	 * data.
	 */
	b	cl_end

.align	5
	nop	/* 0 */
	nop	/* 4 */
	nop	/* 8 */
	nop	/* 12 */
	nop	/* 16 */
	nop	/* 20 */
	nop	/* 24 */
cl_end:	orlo	$r1, $r1, 0xfeed	/* 28, last word in cache line. */
	TESTPOINT	TP_USER, 1
	nop
	b	success

loop:
	b	loop

success:
	SUCCESS
