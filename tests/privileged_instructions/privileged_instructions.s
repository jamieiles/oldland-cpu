.include "common.s"

.globl _start
_start:
	mov	$r12, 0x60 /* I+D cache enable. */
	scr	1, $r12
	movhi	$r0, %hi(ex_table)
	orlo	$r0, $r0, %lo(ex_table)
	scr	0, $r0

	/* Enter user mode. */
	gcr	$r1, 1
	or	$r1, $r1, 0x100 /* User mode */
	scr	1, $r1

__cache_aborts:
	cache	$r0, 3
	TESTPOINT TP_USER, 0
__rfe_aborts:
	rfe
	TESTPOINT TP_USER, 1
__scr_aborts:
	scr	1, $r0
	TESTPOINT TP_USER, 2
__gcr_aborts:
	gcr	$r0, 1
	TESTPOINT TP_USER, 3


	SUCCESS

illegal_instr:
	TESTPOINT TP_USER, 0x100
	rfe

bad_vector:
	FAILURE

	.balign	64
ex_table:
	b	bad_vector	/* RESET */
	b	illegal_instr	/* ILLEGAL_INSTR */
	b	bad_vector	/* SWI */
	b	bad_vector	/* IRQ */
	b	bad_vector	/* IFETCH_ABORT */
	b	bad_vector	/* DATA_ABORT */
