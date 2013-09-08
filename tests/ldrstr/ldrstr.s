.include "common.s"

.globl _start
_start:
	movhi	$r0, 0xdead
	orlo	$r0, $r0, 0xbeef

	/* Simple 32-bit load, make sure it matches a known constant. */
	ldr32	$r1, deadbeef
	cmp	$r0, $r1
	bne	failure

	xor	$r2, $r2, $r2
	movhi	$r3, %hi(deadbeef)
	orlo	$r3, $r3, %lo(deadbeef)

	/* Check that 8-bit reads get the correct values including masking. */
byte_accesses:
	movhi	$r6, %hi(destination)
	orlo	$r6, $r6, %lo(destination)

	/* [7:0] */
	ldr8	$r4, [$r3, 0]
	str8	$r4, [$r6, 0]
	lsl	$r4, $r4, 0
	or	$r2, $r2, $r4

	/* [15:8] */
	ldr8	$r4, [$r3, 1]
	str8	$r4, [$r6, 1]
	lsl	$r4, $r4, 8
	or	$r2, $r2, $r4

	/* [23:16] */
	ldr8	$r4, [$r3, 2]
	str8	$r4, [$r6, 2]
	lsl	$r4, $r4, 16
	or	$r2, $r2, $r4

	/* [31:24] */
	ldr8	$r4, [$r3, 3]
	str8	$r4, [$r6, 3]
	lsl	$r4, $r4, 24
	or	$r2, $r2, $r4

	cmp	$r2, $r1
	bne	failure

	/* and read that back. */
	ldr32	$r2, destination
	cmp	$r2, $r1
	bne	failure

	/* Now do the same but for 16-bits. */
hword_accesses:
	xor	$r2, $r2, $r2

	/* [15:0] */
	ldr16	$r4, [$r3, 0]
	str16	$r4, [$r6, 0]
	lsl	$r4, $r4, 0
	or	$r2, $r2, $r4

	/* [31:16] */
	ldr16	$r4, [$r3, 2]
	str16	$r4, [$r6, 2]
	lsl	$r4, $r4, 16
	or	$r2, $r2, $r4

	cmp	$r2, $r1
	bne	failure

	ldr32	$r2, destination
	cmp	$r2, $r1
	bne	failure

	SUCCESS

failure:
	FAILURE

deadbeef:
	.long	0xdeadbeef
destination:
	.long	0x00000000
