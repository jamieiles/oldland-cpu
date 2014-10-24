.include "common.s"

.globl _start
_start:
	mov	$r12, 0x60 /* I+D cache enable. */
	scr	1, $r12
	or	$r0, $r0, 1
	add	$r0, $r0, 1
	nop
	nop
	nop
	add	$r0, $r0, 1
	nop
	nop
	add	$r0, $r0, 1
	nop
	add	$r0, $r0, 1
	add	$r0, $r0, 1

	cmp	$r0, 6
	beq	success

	FAILURE

success:
	SUCCESS
