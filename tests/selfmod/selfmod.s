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
	mov	$r12, 0x60 /* I+D cache enable. */
	scr	1, $r12
	ldr32	$r0, loop
	str32	$r0, target
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
        /* New cache line. */
	TESTPOINT	TP_USER, 1
	nop
	b	patch


.align  5
patch:
	ldr32	$r0, incr3
	str32	$r0, ptarget
	nop
	nop
	nop
ptarget:
	nop
	nop
	nop
	/* Invalidate cache line. */
	movhi	$r2, %hi(patch)
	orlo	$r2, $r2, %lo(patch)
	/* 32-byte cache line size only, assume that tag bits are clear. */
	lsr	$r2, $r2, 5
	cache	$r2, 0
	cmp	$r3, 1
	beq	success
	b	ptarget

	FAILURE

loop:
	b	loop

incr3:
	add	$r3, $r3, 1

success:
	SUCCESS
