.include "common.s"

.globl	_start
_start:
	mov	$r12, 0x60 /* I+D cache enable. */
	scr	1, $r12
	/*
	 * Wait for the SDRAM to be configured.  The controller lives at
	 * 0x800001000, bit 0 in any register in the 4KB space indicates
	 * configuration is done.
	 */
	movhi	$r0, 0x8000
	orlo	$r9, $r0, 0x1000
config_loop:
	ldr32	$r1, [$r9, 0]
	cmp	$r1, 0x0
	beq	config_loop

1:
	movhi	$r0, %hi(sdram_fn)
	orlo	$r0, $r0, %lo(sdram_fn)
	TESTPOINT	TP_USER, 0
	call	$r0
	SUCCESS

	.section ".text.sdram", "ax"
sdram_fn:
	TESTPOINT	TP_USER, 1
	add	$r5, $r5, 1
	add	$r6, $r6, 1
	ret
