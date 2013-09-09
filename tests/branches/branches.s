.include "common.s"

.macro	compare_ints	inta, intb

	movhi	$r0, ((\inta >> 16) & 0xffff)
	orlo	$r0, $r0, (\inta & 0xffff)

	movhi	$r1, ((\intb >> 16) & 0xffff)
	orlo	$r1, $r1, (\intb & 0xffff)

	/* BNE/BEQ */
	cmp	$r0, $r1
	beq	failure
	bne	1f
	FAILURE

1:
	/* BGT/BLT */
	cmp	$r0, $r1
	bgt	failure
	blt	2f
	FAILURE
2:
.endm

.globl _start
_start:
	compare_ints	1, 2
	compare_ints	1, 0xfffffffe
	SUCCESS

failure:
	FAILURE
