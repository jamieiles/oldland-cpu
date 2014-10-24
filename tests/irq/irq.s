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

	movhi	$r1, 0x8000
	orlo	$r1, $r1, 0x2000

	/* Enable interrupts. */
	gcr	$r0, 1
	bst	$r0, $r0, 4
	scr	1, $r0

	xor	$r2, $r2, $r2
	add	$r2, $r2, 1
	str32	$r2, [$r1, 0x4]	/* Enable IRQ0. */

	swi	0
	str32	$r2, [$r1, 0xc] /* Fire IRQ0. */
	swi	0

	TESTPOINT	TP_USER, 1

	swi	0
	str32	$r2, [$r1, 0xc] /* Fire IRQ0. */
	swi	0

	TESTPOINT	TP_USER, 1

	SUCCESS

irq_vector:
	str32	$r3, [$r1, 0xc] /* Clear IRQs. */
	TESTPOINT	TP_USER, 0
	rfe

swi_vector:
	TESTPOINT	TP_USER, 2
	rfe

bad_vector:
	b	bad_vector

	.balign	64
ex_table:
	b	bad_vector	/* RESET */
	b	bad_vector	/* ILLEGAL_INSTR */
	b	swi_vector	/* SWI */
	b	irq_vector	/* IRQ */
	b	bad_vector	/* IFETCH_ABORT */
	b	bad_vector	/* DATA_ABORT */

.rept	32
	.long		0
.endr
stack_top:
