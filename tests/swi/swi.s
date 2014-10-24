.include "common.s"

.globl _start
_start:
	mov	$r12, 0x60 /* I+D cache enable. */
	scr	1, $r12
	xor	$sp, $sp, $sp
	orlo	$sp, $sp, 0x800

	movhi	$r0, %hi(ex_table)
	orlo	$r0, $r0, %lo(ex_table)
	scr	0, $r0

	swi	0
	TESTPOINT	TP_USER, 1 /*
				    * Make sure we return to the correct
				    * address.
				    */
	SUCCESS

swi_vector:
	push	$r0
	gcr	$r0, 3
	TESTPOINT	TP_USER, 0
	pop	$r0
	rfe

bad_vector:
	FAILURE

	.balign	64
ex_table:
	b	bad_vector	/* RESET */
	b	bad_vector	/* ILLEGAL_INSTR */
	b	swi_vector	/* SWI */
	b	bad_vector	/* IRQ */
	b	bad_vector	/* IFETCH_ABORT */
	b	bad_vector	/* DATA_ABORT */
