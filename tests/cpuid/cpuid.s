.include "common.s"

.globl _start
_start:
	cpuid	$r0, 0
	cpuid	$r1, 1
	cpuid	$r2, 2
	cpuid	$r3, 3
	cpuid	$r4, 4
	SUCCESS
