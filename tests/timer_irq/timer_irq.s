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

	movhi	$r5, 0x8000
	orlo	$r5, $r5, 0x2000
	or	$r6, $r6, 0x1
	str32	$r6, [$r5, 0x4]

	/* Enable interrupts. */
	gcr	$r0, 1
	bst	$r0, $r0, 4
	scr	1, $r0

	movhi	$r2, 0x0000
	orlo	$r2, $r2, 0x8
	str32	$r2, [$r1, 0x4] /* Reload value. */

	xor	$r2, $r2, $r2
	orlo	$r2, $r2, 0x6 /* One-shot, enabled, irq enabled. */
	str32	$r2, [$r1, 0x8]

1:
	ldr32	$r3, irq_processed
	cmp	$r3, 0
	beq	1b

	SUCCESS

irq_processed:
	.long	0

irq_vector:
	add	$r4, $r4, 1
	str32	$r4, irq_processed
	str32	$r4, [$r1, 0xc]
	/* Restart interrupted instruction. */
	gcr	$r7, 3
	sub	$r7, $r7, 4
	scr	3, $r7
	rfe

bad_vector:
	FAILURE

	.balign	64
ex_table:
	b	bad_vector	/* RESET */
	b	bad_vector	/* ILLEGAL_INSTR */
	b	bad_vector	/* SWI */
	b	irq_vector	/* IRQ */
	b	bad_vector	/* IFETCH_ABORT */
	b	bad_vector	/* DATA_ABORT */

.rept	32
	.long		0
.endr
stack_top:
