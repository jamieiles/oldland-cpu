.include "common.s"

.globl _start
_start:
	mov	$r12, 0x60 /* I+D cache enable. */
	scr	1, $r12
	xor	$r0, $r0, $r0
	xor	$r1, $r1, $r1
	xor	$r2, $r2, $r2

	/* 0xffffffff + 1, */
	movhi	$r0, 0xffff
	orlo	$r0, $r0, 0xffff
	add	$r1, $r0, 1
	addc	$r2, $r2, 0

	cmp	$r1, 0
	bne	failure

	cmp	$r2, 1
	bne	failure

	mov	$r0, 1
	lsl	$r0, $r0, 31
	asr	$r0, $r0, 31
	cmp	$r0, -1
	bne	failure

	SUCCESS

failure:
	FAILURE
