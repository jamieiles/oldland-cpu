.include "common.s"

.globl _start
_start:
	movhi	$r0, %hi(ex_table)
	orlo	$r0, $r0, %lo(ex_table)
	scr	0, $r0

	xor	$r1, $r1, $r1
	gcr	$r1, 0
	cmp	$r0, $r1
	beq	success
	FAILURE

success:
	SUCCESS

1:
	b	1b

	.balign	64
ex_table:
