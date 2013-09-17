.include "common.s"

.globl _start
_start:
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

	SUCCESS

failure:
	FAILURE
