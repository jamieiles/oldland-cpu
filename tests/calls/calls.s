.include "common.s"

.globl _start
_start:
	movhi		$sp, %hi(stack_top)
	orlo		$sp, $sp, %lo(stack_top)
	call		f1
	TESTPOINT	TP_USER, 4
	SUCCESS

f1:
	push		$lr
	TESTPOINT	TP_USER, 0
	call		f2
	TESTPOINT	TP_USER, 3
	pop		$lr
	ret

f2:
	push		$lr
	TESTPOINT	TP_USER, 1
	or		$r1, $r1, $r1
	TESTPOINT	TP_USER, 2
	pop		$lr
	ret

.rept	32
	.long		0
.endr
stack_top:
