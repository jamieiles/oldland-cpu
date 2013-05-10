.globl _start
_start:
	movhi	$r2, 0x8000 # UART at 0x80000000

echo_loop:
	call	read_char
	call	do_echo
	b	echo_loop

	/*
	 * Read a character, uart base address is in r2, read character
	 * returned in r0.
	 */
read_char:
	ldr32	$r0, [$r2, 0x4] # Read status reg
	and	$r0, $r0, 0x2
	cmp	$r0, 0x2	# RX data ready
	bne	read_char
	ldr32	$r0, [$r2, 0x0]
	ret

do_echo:
	/* Capitalize lower case, print everything else as it is. */
	cmp	$r0, 0x7a
	bgt	print
	cmp	$r0, 0x61
	blt	print

	xor	$r0, $r0, 0x20
print:
	str32	$r0, [$r2, 0x0]
	ret
