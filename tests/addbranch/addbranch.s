.include "common.s"

.globl _start
_start:
	xor	$r0, $r0, $r0
	add	$r0, $r0, 1
	b	1f
	1:
	add	$r0, $r0, 1
	b	2f
	2:
	add	$r0, $r0, 1
	b	3f
	3:
	add	$r0, $r0, 1
	b	4f
	4:
	add	$r0, $r0, 1
	b	5f
	5:
	add	$r0, $r0, 1

	cmp	$r0, 6
	beq	success

	FAILURE

success:
	SUCCESS
