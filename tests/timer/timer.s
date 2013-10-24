.include "common.s"

.globl _start
_start:
	movhi	$r0, %hi(ex_table)
	orlo	$r0, $r0, %lo(ex_table)
	scr	0, $r0

	movhi	$sp, %hi(stack_top)
	orlo	$sp, $sp, %lo(stack_top)

	movhi	$r1, 0x8000
	orlo	$r1, $r1, 0x3000

	movhi	$r2, 0xffff
	orlo	$r2, $r2, 0xffff
	str32	$r2, [$r1, 0x4] /* Reload value. */

	xor	$r2, $r2, $r2
	orlo	$r2, $r2, 0x3 /* Periodic, enabled. */
	str32	$r2, [$r1, 0x8]

	ldr32	$r2, [$r1, 0x0]
	TESTPOINT	TP_USER, 0

	nop
	nop
	nop

	ldr32	$r2, [$r1, 0x0]
	TESTPOINT	TP_USER, 1

	nop
	nop
	nop

	str32	$r3, [$r1, 0x8] /* Disable timer. */
	ldr32	$r2, [$r1, 0x0]
	TESTPOINT	TP_USER, 2

	nop
	nop
	ldr32	$r2, [$r1, 0x0]
	TESTPOINT	TP_USER, 3

	SUCCESS

bad_vector:
	FAILURE

	.balign	64
ex_table:
	b	bad_vector	/* RESET */
	b	bad_vector	/* ILLEGAL_INSTR */
	b	bad_vector	/* SWI */
	b	bad_vector	/* IRQ */
	b	bad_vector	/* IFETCH_ABORT */
	b	bad_vector	/* DATA_ABORT */

.rept	32
	.long		0
.endr
stack_top:
