.include "common.s"

.globl _start
_start:
	b	do_setup
	.long   cpu_version - 0x10000000
	.long   date - 0x10000000
	.long   fdt - 0x10000000


	.align	4
	.section ".text"
.globl do_setup
do_setup:
	movhi	$r0, %hi(ex_table)
	orlo	$r0, $r0, %lo(ex_table)
	scr	0, $r0

	/* clear BSS segments */
	movhi	$r4, %hi(_bss_start)
	orlo	$r4, $r4, %lo(_bss_start)
	movhi	$r5, %hi(_bss_end)
	orlo	$r5, $r5, %lo(_bss_end)
	mov	$r3, 0
_clear_bss:
	str8	$r3, [$r4, 0]
	cmp	$r4, $r5
	beq	1f
	add	$r4, $r4, 1
	b	_clear_bss

1:
	call	sdram_init
	call	setup_stack
	call	root
end:
	b	end

setup_stack:
	/* Top of SRAM. */
	movhi	$sp, 0x0000
	orlo	$sp, $sp, 0x0ffc

	ret

__data_abort:
	mov	$r0, $lr
	gcr	$r1, 4
	call	data_abort_handler

	.balign	64
ex_table:
reset:
	b	reset
illegal_instr:
	b	illegal_instr
swi:
	b	swi
irq:
	b	irq
ifetch_abort:
	b	ifetch_abort	
data_abort:
	b	__data_abort
