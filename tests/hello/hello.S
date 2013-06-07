.globl _start
_start:
	movhi	$r4, %hi(hello_start)
	add	$r2, $r4, 0
	or	$r4, $r4, %lo(hello_start)
	or	$r2, $r2, %lo(hello_end)

copy_loop:
	cmp	$r2, $r4
	beq	done
	ldr8	$r0, [$r4, 0x0]
	call	putchar

	add	$r4, $r4, 1
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

/*
 * Write a single character to the UART, character to put is in r0,
 * clobbers r0 and r1.
 */
.globl putchar
putchar:
	movhi	$r1, 0x8000 # UART at 0x80000000
	str32	$r0, [$r1, 0x0]

not_empty:
	ldr32	$r0, [$r1, 0x4]
	and	$r0, $r0, 0x1
	cmp	$r0, 1
	bne	not_empty

	ret

.section .rodata
hello_start:
	.ascii	"Hello, world!"
hello_end:
