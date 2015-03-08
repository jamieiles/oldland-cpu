.include "common.s"

.globl _start
_start:
	mov	$r12, 0x60 /* I+D cache enable. */
	scr	1, $r12

        mov     $r0, 0xff /* Only 4 LSB's can be set. */
        mov     $r1, 0

        spsr    $r0
        gpsr    $r8
        TESTPOINT TP_USER, 0

        cmp     $r1, 0
        gpsr    $r8
        TESTPOINT TP_USER, 1

success:
	SUCCESS
