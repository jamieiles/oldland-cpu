.include "common.s"

.globl _start
_start:
	mov	$r0, 1
	lsl	$r0, $r0, 31
	asr	$r0, $r0, 31
	cmp	$r0, -1
	bne	failure

	mov	$r0, 0xff
	mov	$r1, 0xa5
	and	$r2, $r0, $r1
	cmp	$r2, 0xa5
	bne	failure

	mov	$r0, 0x01
	and	$r2, $r0, $r1
	cmp	$r2, 0x01
	bne	failure

	SUCCESS

failure:
	FAILURE
