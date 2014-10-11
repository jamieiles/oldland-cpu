.include "common.s"

.globl sdram_init
sdram_init:
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

	ret
