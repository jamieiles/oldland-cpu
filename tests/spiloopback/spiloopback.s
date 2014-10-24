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
	orlo	$r1, $r1, 0x4000

	movhi	$r4, 0x8000
	orlo	$r4, $r4, 0x6000

	movhi	$r7, 0x00
	orlo	$r2, $r7, 0xaa
	str8	$r2, [$r4, 0] /* transmit data. */
	orlo	$r2, $r7, 0x55
	str8	$r2, [$r4, 1] /* transmit data. */
	orlo	$r2, $r7, 0x55
	str8	$r2, [$r4, 2] /* transmit data. */
	orlo	$r2, $r7, 0xaa
	str8	$r2, [$r4, 3] /* transmit data. */

	movhi	$r2, 0x0
	orlo	$r2, $r2, 0x0208
	str32	$r2, [$r1, 0x0] /* loopback enabled, x8 divider. */

	movhi	$r2, 0x0
	orlo	$r2, $r2, 0x00
	str32	$r2, [$r1, 0x4] /* no chip select enabled. */

	TESTPOINT TP_USER, 0

	movhi	$r2, 0x0001 /* transmit go. */
	orlo	$r2, $r2, 0x0004 /* 4 byte transfer. */
	str32	$r2, [$r1, 0x8] /* xfer control register. */

	movhi	$r3, 0x2
busy:
	ldr32	$r2, [$r1, 0x8]
	and	$r2, $r2, $r3
	cmp	$r2, $r3
	beq	busy

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
