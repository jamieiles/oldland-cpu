.include "common.s"

.globl _start
_start:
	mov	$r12, 0x60 /* I+D cache enable. */
	scr	1, $r12
	/* Wait for SDRAM to initialize. */
	movhi	$r0, 0x8000
	orlo	$r0, $r0, 0x1000
1:
	ldr32	$r1, [$r0, 0]
	cmp	$r1, 0x0
	beq	1b

	movhi	$r3, 0x2000
        orlo    $r0, $r3, 0x0
        orlo    $r4, $r3, 32768

        /*
         * Write addresses to incrementing addresses such that we'll wrap
         * around indexes and force eviction.  Load the address first to
         * trigger a line-fill.
         */
2:
	cmp	$r0, $r4
	beq	success

        ldr32   $r8, [$r0, 0]
	str32	$r0, [$r0, 0]
	add	$r0, $r0, 1024

	b	2b

success:
	TESTPOINT	TP_USER, 0
	SUCCESS
