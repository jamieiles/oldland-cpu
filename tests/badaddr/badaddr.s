.include "common.s"

.globl _start
_start:
	movhi	$r0, 0x9000 /* Unmapped address. */
	ldr32	$r1, [$r0, 0]

success:
	SUCCESS

1:
	b	1b
