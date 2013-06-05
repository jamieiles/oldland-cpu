.globl _start
_start:
	/*
	 * Wait for the SDRAM to be configured.  The controller lives at
	 * 0x800001000, bit 0 in any register in the 4KB space indicates
	 * configuration is done.
	 */
	movhi	$r0, 0x8000
	add	$r0, $r0, 0x01000
config_loop:
	ldr32	$r1, [$r0, 0]
	cmp	$r1, $r2
	beq	config_loop

	xor	$r0, $r0, $r0
	xor	$r1, $r1, $r1
	xor	$r2, $r2, $r2
	movhi	$r0, %hi(str_start)
	add	$r1, $r0, 0
	or	$r0, $r0, %lo(str_start)
	or	$r1, $r1, %lo(str_end)
	movhi	$r2, 0x2000 # SDRAM at 0x20000000

copy_loop:
	cmp	$r1, $r0
	beq	copied
	ldr8	$r3, [$r0, 0x0]
	str8	$r3, [$r2, 0x0]
	add	$r0, $r0, 1
	add	$r2, $r2, 1
	b	copy_loop

copied:
	movhi	$r0, 0x2000
	movhi	$r1, 0x2000
	add	$r1, $r1, str_len
	movhi	$r2, 0x8000 # UART at 0x80000000
	xor	$r3, $r3, $r3
	add	$r3, $r3, 1

output_loop:
	cmp	$r0, $r1
	beq	done
	ldr8	$r4, [$r0, 0x0]
	str32	$r4, [$r2, 0x0]

not_empty:
	ldr32	$r5, [$r2, 0x4]
	and	$r5, $r5, 0x1
	cmp	$r5, $r3
	bne	not_empty

	add	$r0, $r0, 1
	b	output_loop

done:
	or	$r3, $r3, $r3
	.long	0xffffffff # Trap to test env

.section .rodata
str_start:
	.ascii	"SDRAM!"
str_end:

.equ str_len, str_end - str_start
