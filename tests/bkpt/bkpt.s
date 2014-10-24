.include "common.s"

.globl _start
_start:
	mov	$r12, 0x60 /* I+D cache enable. */
	scr	1, $r12
	nop
	nop
	nop
	TESTPOINT	TP_USER, 0
	nop
	nop
	TESTPOINT	TP_USER, 1
	nop
	nop
	SUCCESS
