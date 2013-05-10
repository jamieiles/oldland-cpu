.globl _start
_start:
	movhi	$r2, 0x8000 # UART at 0x80000000

echo_loop:
	ldr32	$r0, [$r2, 0x4] # Read status reg
	and	$r0, $r0, 0x2
	cmp	$r0, 0x2	# RX data ready
	beq	do_echo
	b	echo_loop

do_echo:
	ldr32	$r1, [$r2, 0x0]

	/* Capitalize lower case, print everything else as it is. */
	cmp	$r1, 0x7a
	bgt	print
	cmp	$r1, 0x61
	blt	print

	xor	$r1, $r1, 0x20
print:
	str32	$r1, [$r2, 0x0]
	b	echo_loop
