.globl _start
_start:
	movhi	$r0, %hi(hello_start)
	add	$r1, $r0, 0
	or	$r0, $r0, %lo(hello_start)
	or	$r1, $r1, %lo(hello_end)
	movhi	$r2, 0x8000 # UART at 0x80000000

copy_loop:
	cmp	$r1, $r0
	beq	done
	ldr8	$r4, [$r0, 0x0]
	str32	$r4, [$r2, 0x0]
	add	$r0, $r0, 1
	b	copy_loop

done:
	or	$r3, $r3, $r3
	or	$r3, $r3, $r3
	or	$r3, $r3, $r3
	or	$r3, $r3, $r3
	or	$r3, $r3, $r3
	or	$r3, $r3, $r3
	or	$r3, $r3, $r3
	or	$r3, $r3, $r3
	or	$r3, $r3, $r3
	or	$r3, $r3, $r3
	or	$r3, $r3, $r3
	.long	0xffffffff # Trap to test env

.section .rodata
hello_start:
	.ascii	"Hello, world!"
hello_end:
