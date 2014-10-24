.include "common.s"

.globl _start
_start:
	mov	$r12, 0x60 /* I+D cache enable. */
	scr	1, $r12
	cpuid	$r0, 0
	cpuid	$r1, 1
	cpuid	$r2, 2
	cpuid	$r3, 3
	cpuid	$r4, 4
	SUCCESS
