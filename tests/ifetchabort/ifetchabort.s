.include "common.s"

.globl _start
_start:
	xor	$sp, $sp, $sp
	orlo	$sp, $sp, 0x800

	movhi	$r0, %hi(ex_table)
	orlo	$r0, $r0, %lo(ex_table)
	scr	0, $r0

	movhi	$r2, 0x9000
	b	$r2

	FAILURE

end:
	SUCCESS

ifetch_abort:
	TESTPOINT	TP_USER, 0
	push	$r0
	movhi	$r0, %hi(end)
	orlo	$r0, $r0, %lo(end)
	scr	3, $r0
	pop	$r0
	rfe

bad_vector:
	FAILURE

	.balign	64
ex_table:
	b	bad_vector	/* RESET */
	b	bad_vector	/* ILLEGAL_INSTR */
	b	bad_vector	/* SWI */
	b	bad_vector	/* IRQ */
	b	ifetch_abort	/* IFETCH_ABORT */
	b	bad_vector	/* DATA_ABORT */
