.include "common.s"

.globl _start
_start:
	mov	$r12, 0x60 /* I+D cache enable. */
	scr	1, $r12
	/* Wait for SDRAM to initialize. */
	movhi	$r0, 0x8000
	orlo	$r0, $r0, 0x1000
1:
	ldr32	$r1, [$r0, 0]
	cmp	$r1, 0x0
	beq	1b

	movhi	$r0, 0x2000
        orlo    $r0, $r0, 0x0

	/*
	 * Read a line into memory.
	 */
	ldr32	$r10, [$r0, 0]

	/* Write incrementing integers to SDRAM. */
	mov	$r1, 0
2:
	cmp	$r1, 16
	bgt	written
	str32	$r1, [$r0, 0]
	add	$r0, $r0, 4
	add	$r1, $r1, 4
	b	2b

written:
	/* Flush those lines to memory and invalidate them. */
	mov	$r0, 0
	cache	$r0, 2
	cache	$r0, 1
	nop

success:
	TESTPOINT	TP_USER, 0
	nop
	SUCCESS
