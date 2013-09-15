.globl _start
_start:
	b	$r0
	/* Offsets from here to the version strings, not executable code. */
	.long	cpu_version
	.long	date
