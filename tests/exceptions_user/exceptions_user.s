.include "common.s"

.globl _start
_start:
	mov	$r12, 0x60 /* I+D cache enable. */
	scr	1, $r12

	mov	$sp, 0xffc

	movhi	$r0, %hi(ex_table)
	orlo	$r0, $r0, %lo(ex_table)
	scr	0, $r0

	/* Enter user mode. */
	gcr	$r1, 1
	or	$r1, $r1, 0x100 /* User mode */
	scr	1, $r1

__swi:
	TESTPOINT TP_USER, 0
	swi	0
	TESTPOINT TP_USER, 1

__data_abort:
	movhi	$r0, %hi(0xf0000000)
	orlo	$r0, $r0, %lo(0xf0000000)
	ldr32	$r1, [$r0, 0]
	TESTPOINT TP_USER, 2

__illegal_instruction:
	.long	0xd0000000
	TESTPOINT TP_USER, 3

__ifetch_abort:
	mov	$r2, 1f
	b	$r0
1:
	TESTPOINT TP_USER, 4

	SUCCESS

swi_vector:
	TESTPOINT TP_USER, 0x100
	rfe

dabort_vector:
	TESTPOINT TP_USER, 0x200
	rfe

illegal_instr:
	TESTPOINT TP_USER, 0x300
	rfe

ifetch_vector:
	TESTPOINT TP_USER, 0x400
	scr	3, $r2
	rfe

bad_vector:
	FAILURE

	.balign	64
ex_table:
	b	bad_vector	/* RESET */
	b	illegal_instr	/* ILLEGAL_INSTR */
	b	swi_vector	/* SWI */
	b	bad_vector	/* IRQ */
	b	ifetch_vector	/* IFETCH_ABORT */
	b	dabort_vector	/* DATA_ABORT */
