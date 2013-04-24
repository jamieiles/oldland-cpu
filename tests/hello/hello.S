.globl _start
_start:
	movhi	$r0, %hi(hello_start)
	mov	$r1, $r0
	or	$r0, $r0, %lo(hello_start)
	or	$r1, $r1, %lo(hello_end)
	movhi	$r2, 0x8000 # UART at 0x80000000
	mov	$r3, $r0

copy_loop:
	sub	$r4, $r1, $r3
	beq	done
	ldr8	$r4, [$r1, 0x0]
	str8	$r2, [$r4, 0x0]
	add	$r1, $r1, 1
	b	copy_loop

done:
	b	done
	ldr32	$r5, done_data

.section .rodata
hello_start:
	.ascii	"Hello, world!"
hello_end:

done_data:
	.long	0xdefaced0
