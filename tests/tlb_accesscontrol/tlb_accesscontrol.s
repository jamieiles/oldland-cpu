.include "common.s"

.equ	DTLB_STORE_VIRT, 4
.equ	DTLB_STORE_PHYS, 5
.equ	ITLB_STORE_VIRT, 6
.equ	ITLB_STORE_PHYS, 7

.equ	R, 1
.equ	W, 2
.equ	RW, 3

.macro map_data_page address, perms
	movhi	$r0, %hi(\address)
	orlo	$r0, $r0, %lo(\address)
	or	$r0, $r0, \perms
	cache	$r0, DTLB_STORE_VIRT

	movhi	$r0, %hi(\address)
	orlo	$r0, $r0, %lo(\address)
	cache	$r0, DTLB_STORE_PHYS
.endm

.macro map_instruction_page address, perms
	movhi	$r0, %hi(\address)
	orlo	$r0, $r0, %lo(\address)
	or	$r0, $r0, \perms
	cache	$r0, ITLB_STORE_VIRT

	movhi	$r0, %hi(\address)
	orlo	$r0, $r0, %lo(\address)
	cache	$r0, ITLB_STORE_PHYS
.endm

.globl _start
_start:
	movhi	$r0, %hi(ex_table)
	orlo	$r0, $r0, %lo(ex_table)
	scr	0, $r0

	/* Install miss handlers. */
	movhi	$r0, %hi(dtlb_miss_handler)
	orlo	$r0, $r0, %lo(dtlb_miss_handler)
	scr	5, $r0
	movhi	$r0, %hi(itlb_miss_handler)
	orlo	$r0, $r0, %lo(itlb_miss_handler)
	scr	6, $r0

validate_no_mmu_access:
	movhi	$r7, 0xdead
	orlo	$r7, $r7, 0xbeef
	movhi	$r8, %hi(sdram_symbol)
	orlo	$r8, $r8, %lo(sdram_symbol)
	str32	$r7, [$r8, 0]
	ldr32	$r7, [$r8, 0]
	TESTPOINT TP_USER, 0

	/* Add an identity mapping for the first page. */
	map_data_page 0x00000000, RW
	map_instruction_page 0x00000000, R

	/* Map in the SDRAM first page. */
	map_data_page 0x20000000, 0
	map_instruction_page 0x20000000, 0

	/* Enable caches+TLB. */
	nop
	nop
	nop
	nop
	nop
	mov	$r1, 0xe0
	scr	1, $r1

validate_no_perms_data_aborts:
	mov	$r7, 0
	ldr32	$r7, [$r8, 0]
	TESTPOINT TP_USER, 1
	str32	$r7, [$r8, 0]
	TESTPOINT TP_USER, 2

validate_read_only:
	map_data_page 0x20000000, R
	ldr32	$r7, [$r8, 0]
	TESTPOINT TP_USER, 3
	str32	$r7, [$r8, 0]
	TESTPOINT TP_USER, 4

validate_write_only:
	map_data_page 0x20000000, W
	ldr32	$r7, [$r8, 0]
	TESTPOINT TP_USER, 5
	str32	$r7, [$r8, 0]
	TESTPOINT TP_USER, 6

validate_no_exec:
	map_instruction_page 0x20000000, 0
	movhi	$r9, %hi(sdram_text)
	orlo	$r9, $r9, %lo(sdram_text)
	mov	$lr, 1f
	call	$r9
1:
	TESTPOINT TP_USER, 7

validate_exec:
	map_instruction_page 0x20000000, R
	mov	$lr, 2f
	call	$r9
2:
	TESTPOINT TP_USER, 8

	SUCCESS

dtlb_miss_handler:
itlb_miss_handler:
	FAILURE

bad_vector:
	FAILURE

data_abort:
	TESTPOINT TP_USER, 0x100
	rfe

ifetch_abort:
	TESTPOINT TP_USER, 0x200
	ret

	.balign	64
ex_table:
	b	bad_vector	/* RESET */
	b	bad_vector	/* ILLEGAL_INSTR */
	b	bad_vector	/* SWI */
	b	bad_vector	/* IRQ */
	b	ifetch_abort	/* IFETCH_ABORT */
	b	data_abort	/* DATA_ABORT */

	.section ".text.sdram"
sdram_text:
	nop
	nop
	TESTPOINT TP_USER, 0x300
	ret

	.balign 128
sdram_symbol:
	.long	0
