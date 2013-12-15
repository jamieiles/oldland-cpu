.include "common.s"

.globl _start
_start:
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
