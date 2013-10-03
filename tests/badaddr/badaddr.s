.include "common.s"

.globl _start
_start:
	movhi	$r0, %hi(ex_table)
	orlo	$r0, $r0, %lo(ex_table)
	scr	0, $r0

	movhi		$sp, %hi(stack_top)
	orlo		$sp, $sp, %lo(stack_top)

	movhi	$r0, 0x9000 /* Unmapped address. */
	ldr32	$r1, [$r0, 0]

success:
	SUCCESS

data_abort:
	push	$r0
	push	$r1

	gcr	$r1, 4
	cmp	$r1, $r0
	bne	failure

	pop	$r1
	pop	$r0
	rfe

failure:
	FAILURE

bad_vector:
	FAILURE

	.balign	64
ex_table:
	b	bad_vector	/* RESET */
	b	bad_vector	/* ILLEGAL_INSTR */
	b	bad_vector	/* SWI */
	b	bad_vector	/* IRQ */
	b	bad_vector	/* IFETCH_ABORT */
	b	data_abort	/* DATA_ABORT */

.rept	32
	.long		0
.endr
stack_top:
