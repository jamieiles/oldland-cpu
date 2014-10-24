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

.macro	taken	branch, a, b
	movhi	$r0, %hi(\a)
	orlo	$r0, $r0, %lo(\a)
	movhi	$r1, %hi(\b)
	orlo	$r1, $r1, %lo(\b)
	cmp	$r0, $r1
	\branch	1f
	FAILURE
1:
.endm

.macro	not_taken	branch, a, b
	movhi	$r0, %hi(\a)
	orlo	$r0, $r0, %lo(\a)
	movhi	$r1, %hi(\b)
	orlo	$r1, $r1, %lo(\b)
	cmp	$r0, $r1
	\branch	1f
	b	2f
1:
	FAILURE
2:
.endm

.globl _start
_start:
	mov	$r12, 0x60 /* I+D cache enable. */
	scr	1, $r12
	taken		beq, 0, 0
	not_taken	beq, 0, 1

	taken		bne, 0, 1
	not_taken	bne, 0, 0

	/* Unsigned branch-greater-than. */
	taken		bgt, 1, 0
	taken		bgt, -1, 0
	not_taken	bgt, 0, 1
	not_taken	bgt, 1, 1

	/* Unsigned branch-less-than. */
	taken		blt, 0, 1
	not_taken	blt, 1, 0
	not_taken	blt, 1, 1
	not_taken	blt, -1, 0

	/* Signed branch-greater-than. */
	taken		bgts, -1, -2
	taken		bgts, 1, -1
	not_taken	bgts, 0, 0
	not_taken	bgts, -2, -1

	/* Signed branch-less-than. */
	taken		blts, -2, -1
	taken		blts, -2, 2
	not_taken	blts, 2, -2,
	not_taken	blts, 0, 0

	/* Unsigned branch-greater-equal. */
	taken		bgte, 1, 0
	taken		bgte, 1, 1
	not_taken	bgte, 0, 1

	/* Signd branch-greater-equal. */
	taken		bgtes, 1, 0
	taken		bgtes, 0, -1
	taken		bgtes, 0, 0
	not_taken	bgtes, 1, 2

	/* Unsigned branch-less-equal. */
	taken		blte, 0, 1
	taken		blte, 1, 1
	not_taken	blte, 1, 0

	/* Signd branch-less-equal. */
	taken		bltes, 0, 1
	taken		bltes, -1, 0
	taken		bltes, 0, 0
	not_taken	bltes, 2, 1

	SUCCESS

failure:
	FAILURE
