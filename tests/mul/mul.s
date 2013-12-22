.include "common.s"

.globl _start
_start:
	mul	$r0, $r0, 0
	TESTPOINT	TP_USER, 0

	or	$r1, $r1, 2
	or	$r2, $r2, 4
	mul	$r0, $r1, $r2
	TESTPOINT	TP_USER, 8

	xor	$r1, $r1, $r1
	or	$r1, $r1, 1
	or	$r2, $r2, -1
	mul	$r0, $r1, $r2
	TESTPOINT	TP_USER, 0xffff

	SUCCESS

failure:
	FAILURE
