.include "common.s"

.globl _start
_start:
	movhi	$sp, 0x2000
	orlo	$sp, $sp, 0x1000

	movhi	$r0, %hi(0x0defaced)
	orlo	$r0, $r0, %lo(0x0defaced)
	scr	3, $r0

	mov	$r0, 0xf
	scr	2, $r0

	mov	$r0,  0x100
	mov	$r1,  0x101
	mov	$r2,  0x102
	mov	$r3,  0x103
	mov	$r4,  0x104
	mov	$r5,  0x105
	mov	$r6,  0x106
	mov	$r7,  0x107
	mov	$r8,  0x108
	mov	$r9,  0x109
	mov	$r10, 0x10a
	mov	$r11, 0x10b
	mov	$r12, 0x10c
	mov	$fp,  0x10d
	mov	$lr,  0x10f

	/*
	 * Saving and restoring all registers that an OS would need for
	 * handling IRQS etc.
	 */
	sub	$sp, $sp, 80
	str32	$r0,  [$sp, 0x00]
	str32	$r1,  [$sp, 0x04]
	str32	$r2,  [$sp, 0x08]
	str32	$r3,  [$sp, 0x0c]
	str32	$r4,  [$sp, 0x10]
	str32	$r5,  [$sp, 0x14]
	str32	$r6,  [$sp, 0x18]
	str32	$r7,  [$sp, 0x1c]
	str32	$r8,  [$sp, 0x20]
	str32	$r9,  [$sp, 0x24]
	str32	$r10, [$sp, 0x28]
	str32	$r11, [$sp, 0x2c]
	str32	$r12, [$sp, 0x30]
	str32	$fp,  [$sp, 0x34]
	str32	$sp,  [$sp, 0x38]
	str32	$lr,  [$sp, 0x3c]
	gcr	$r0, 2
	str32	$r0,  [$sp, 0x40] /* Saved PSR. */
	gcr	$r0, 3
	str32	$r0,  [$sp, 0x44] /* FAR. */

irq_restore:
	ldr32	$r1,  [$sp, 0x04]
	ldr32	$r2,  [$sp, 0x08]
	ldr32	$r3,  [$sp, 0x0c]
	ldr32	$r4,  [$sp, 0x10]
	ldr32	$r5,  [$sp, 0x14]
	ldr32	$r6,  [$sp, 0x18]
	ldr32	$r7,  [$sp, 0x1c]
	ldr32	$r8,  [$sp, 0x20]
	ldr32	$r9,  [$sp, 0x24]
	ldr32	$r10, [$sp, 0x28]
	ldr32	$r11, [$sp, 0x2c]
	ldr32	$r12, [$sp, 0x30]
	ldr32	$fp,  [$sp, 0x34]
	/* No need to restore $sp. */
	ldr32	$lr,  [$sp, 0x3c]
	ldr32	$r0,  [$sp, 0x40] /* Saved PSR. */
	scr	2, $r0
	ldr32	$r0,  [$sp, 0x44] /* FAR. */
	scr	3, $r0
	/* Load clobbered $r0. */
	ldr32	$r0,  [$sp, 0x00]
	add	$sp, $sp, 80

	TESTPOINT TP_USER, 0

	SUCCESS
