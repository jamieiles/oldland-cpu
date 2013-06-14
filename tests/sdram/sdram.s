.macro	push	reg
	str32	\reg, [$sp, 0]
	sub	$sp, $sp, 4
.endm

.macro	pop	reg
	add	$sp, $sp, 4
	ldr32	\reg, [$sp, 0]
.endm

.globl _start
_start:
	/*
	 * Wait for the SDRAM to be configured.  The controller lives at
	 * 0x800001000, bit 0 in any register in the 4KB space indicates
	 * configuration is done.
	 */
	movhi	$r0, 0x8000
config_loop:
	ldr32	$r1, [$r0, 0x1000]
	cmp	$r1, 0x0
	beq	config_loop

main:
	/*
	 * Stack pointer, top of SRAM.
	 */
	movhi	$sp, 0x0000
	orlo	$sp, $sp, 0x0ffc


init_mem:
	movhi	$r2, 0x2000 /* Start */
	movhi	$r1, 0x2000 /* End */
	orlo	$r1, $r1, 0x0100

wait_user:
	ldr32	$r3, [$r0, 0x4]
	and	$r3, $r3, 0x2
	cmp	$r3, 0x2
	bne	wait_user

	movhi	$r0, %hi(start_str)
	orlo	$r0, $r0, %lo(start_str)
	call	putstr

1:
	cmp	$r2, $r1
	beq	read_back
	str32	$r2, [$r2, 0]
	add	$r2, $r2, 4
	b	1b

read_back:
	/* Now read back and compare. */
	movhi	$r2, 0x2000
2:
	cmp	$r2, $r1
	beq	done
	ldr32	$r0, [$r2, 0]
	cmp	$r0, $r2
	add	$r2, $r2, 4
	bne	error
	b	2b

error:
	call	put_u32

	push	$r0
	push	$r2

	movhi	$r0, %hi(spacer_str)
	orlo	$r0, $r0, %lo(spacer_str)
	call	putstr

	pop	$r2
	pop	$r0

	or	$r0, $r2, $r2
	call	put_u32
	
	movhi	$r0, %hi(error_str)
	orlo	$r0, $r0, %lo(error_str)
	call	putstr
1:
	b	1b

	/*
	b	2b
	*/

done:
	movhi	$r0, %hi(complete_str)
	orlo	$r0, $r0, %lo(complete_str)
	call	putstr

1:
	b	1b

	/* Write a 32 bit integer to the UART, source passed in $r0. */
.globl put_u32
put_u32:
	/* Push caller save registers. */
	push	$r1
	push	$lr

	/* MSB first. */
	or	$r1, $r0, $r0
	lsr	$r1, $r1, 24
	and	$r1, $r1, 0xff
	call	put_u8

	or	$r1, $r0, $r0
	lsr	$r1, $r1, 16
	and	$r1, $r1, 0xff
	call	put_u8

	or	$r1, $r0, $r0
	lsr	$r1, $r1, 8
	and	$r1, $r1, 0xff
	call	put_u8

	or	$r1, $r0, $r0
	and	$r1, $r1, 0xff
	call	put_u8

	/* Pop caller save registers. */
	pop	$lr
	pop	$r1

	ret

put_u8:
	push	$r1
	push	$r2
	push	$r3
	push	$r4
	push	$lr

	and	$r2, $r1, 0x0f
	and	$r1, $r1, 0xf0
	lsr	$r1, $r1, 4

	movhi	$r3, %hi(hex_table)
	orlo	$r3, $r3, %lo(hex_table)

	add	$r4, $r3, $r1
	ldr8	$r4, [$r4, 0]
	call	putc

	add	$r4, $r3, $r2
	ldr8	$r4, [$r4, 0]
	call	putc

	pop	$lr
	pop	$r4
	pop	$r3
	pop	$r2
	pop	$r1

	ret

	/*
	 * Print a character.
	 */
.globl putc
putc:
	push	$r2
	push	$r0

	movhi	$r2, 0x8000
	str32	$r4, [$r2, 0x0]

not_empty:
	ldr32	$r0, [$r2, 0x4]
	and	$r0, $r0, 0x1
	cmp	$r0, 0x1
	bne	not_empty

	pop	$r0
	pop	$r2

	ret

	/*
	 * Print a string, pointer in $r0.
	 *
	 * Clobbers $r0.
	 */
.globl putstr
putstr:
	push	$r2
	push	$r4
	push	$lr

	or	$r2, $r0, $r0
1:
	ldr8	$r4, [$r2, 0]
	and	$r4, $r4, 0xff
	cmp	$r4, 0
	beq	2f
	call	putc
	add	$r2, $r2, 1
	b	1b

2:
	pop	$lr
	pop	$r4
	pop	$r2

	ret

.pushsection ".rodata"

hex_table:
	.asciz "0123456789abcdef"

start_str:
	.asciz "Start SDRAM test.\n\r"

complete_str:
	.asciz "Complete!"

error_str:
	.asciz " <- mismatch (read/write) \n\r"

spacer_str:
	.asciz " / "

.popsection
