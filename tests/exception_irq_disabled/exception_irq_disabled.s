.include "common.s"

.globl _start
_start:
	mov	$r12, 0x60 /* I+D cache enable. */
	scr	1, $r12
	movhi	$r0, %hi(ex_table)
	orlo	$r0, $r0, %lo(ex_table)
	scr	0, $r0

	movhi	$sp, %hi(stack_top)
	orlo	$sp, $sp, %lo(stack_top)

	/* Enable interrupts. */
	gcr	$r0, 1
	bst	$r0, $r0, 4
	scr	1, $r0

	swi	0

	FAILURE

swi_vector:
	TESTPOINT	TP_USER, 0
	gcr	$r0, 1
	and	$r0, $r0, 16
	cmp	$r0, 16
	beq	failed
	SUCCESS
failed:
	FAILURE

bad_vector:
	b	bad_vector

	.balign	64
ex_table:
	b	bad_vector	/* RESET */
	b	bad_vector	/* ILLEGAL_INSTR */
	b	swi_vector	/* SWI */
	b	bad_vector	/* IRQ */
	b	bad_vector	/* IFETCH_ABORT */
	b	bad_vector	/* DATA_ABORT */

.rept	32
	.long		0
.endr
stack_top:
