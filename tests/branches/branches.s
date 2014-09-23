.include "common.s"

.macro	compare_uints	inta, intb

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

.macro	compare_ints	inta, intb

	movhi	$r0, ((\inta >> 16) & 0xffff)
	orlo	$r0, $r0, (\inta & 0xffff)

	movhi	$r1, ((\intb >> 16) & 0xffff)
	orlo	$r1, $r1, (\intb & 0xffff)

1:
	/* BGT/BLT */
	cmp	$r0, $r1
	bgts	failure
	blts	2f
	FAILURE
2:
.endm

.globl _start
_start:
	compare_uints	1, 2
	compare_uints	1, 0xfffffffe
	compare_uints	0, 0xffffffff

	compare_ints	1, 2
	compare_ints	-1, 1
	compare_ints	-1, 0
	compare_ints	-2, -1
	compare_ints	0x80000000, 0x7fffffff

	/* Unsigned BGTE */
	mov	$r0, 1
	mov	$r1, 1
	cmp	$r1, $r0
	bgte	1f
	FAILURE
1:

	mov	$r0, 1
	mov	$r1, 2
	cmp	$r1, $r0
	bgte	2f
	FAILURE
2:

	mov	$r0, 2
	mov	$r1, 1
	cmp	$r1, $r0
	bgte	failure

	SUCCESS

failure:
	FAILURE
