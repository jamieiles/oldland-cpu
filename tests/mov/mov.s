.include "common.s"

.globl _start
_start:
	movhi		$r0, 0xdead
	orlo		$r0, $r0, 0xbeef

	xor		$r1, $r1, $r1
	mov		$r1, $r0
	TESTPOINT	TP_USER, 0

	xor		$r2, $r2, $r2
	mov		$r2, 0x100
	TESTPOINT	TP_USER, 1

	xor		$r3, $r3, $r3
	mov		$r3, -1
	TESTPOINT	TP_USER, 2

	SUCCESS
