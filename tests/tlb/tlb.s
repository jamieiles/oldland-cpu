.include "common.s"

.equ	IDENTITY_VIRT_MAPPING, 0
.equ	IDENTITY_PHYS_MAPPING, 0
.equ	DTLB_STORE_VIRT, 4
.equ	DTLB_STORE_PHYS, 5
.equ	ITLB_STORE_VIRT, 6
.equ	ITLB_STORE_PHYS, 7

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

	/* Add an identity mapping for the first page. */
	movhi	$r0, %hi(IDENTITY_VIRT_MAPPING)
	orlo	$r0, $r0, %lo(IDENTITY_VIRT_MAPPING)
	cache	$r0, DTLB_STORE_VIRT
	cache	$r0, ITLB_STORE_VIRT

	movhi	$r0, %hi(IDENTITY_PHYS_MAPPING)
	orlo	$r0, $r0, %lo(IDENTITY_PHYS_MAPPING)
	cache	$r0, DTLB_STORE_PHYS
	cache	$r0, ITLB_STORE_PHYS

	/* Enable caches+TLB. */
	nop
	nop
	nop
	nop
	nop
	mov	$r1, 0xe0
	scr	1, $r1

	nop
	nop
	nop
	nop
	nop
	TESTPOINT	TP_USER, 0

_test_dtlb_miss:
	/* Load from an unmapped address, should hit a TLB miss. */
	movhi	$r0, %hi(0x40000000)
	orlo	$r0, $r0, %lo(0x40000000)
	ldr32	$r1, [$r0, 0]
	/*
	 * Now we have inserted an entry in the miss handler we should be able
	 * to execute without a miss.
	 */
	ldr32	$r1, [$r0, 0]


_test_itlb_miss:
	movhi	$r0, %hi(sdram_text)
	orlo	$r0, $r0, %lo(sdram_text)
	call	$r0
	nop
	nop
	/*
	 * Now we have inserted an entry in the miss handler we should be able
	 * to execute without a miss.
	 */
	call	$r0
	nop
	nop

	SUCCESS

dtlb_miss_handler:
	TESTPOINT	TP_USER, 1

	/*
	 * Install a TLB entry for the faulting address.
	 */
	movhi	$r7, %hi(0x40000000)
	orlo	$r7, $r7, %lo(0x40000000)
	cache	$r7, DTLB_STORE_VIRT
	movhi	$r7, %hi(0x00000000)
	orlo	$r7, $r7, %lo(0x00000000)
	cache	$r7, DTLB_STORE_PHYS

	rfe

itlb_miss_handler:
	TESTPOINT	TP_USER, 2

	/*
	 * Install a TLB entry for the faulting address.
	 */
	movhi	$r7, %hi(0x20000000)
	orlo	$r7, $r7, %lo(0x20000000)
	cache	$r7, ITLB_STORE_VIRT
	movhi	$r7, %hi(0x20000000)
	orlo	$r7, $r7, %lo(0x20000000)
	cache	$r7, ITLB_STORE_PHYS

	rfe

bad_vector:
	FAILURE

	.balign	64
ex_table:
	b	bad_vector	/* RESET */
	b	bad_vector	/* ILLEGAL_INSTR */
	b	bad_vector	/* SWI */
	b	bad_vector	/* IRQ */
	b	bad_vector	/* IFETCH_ABORT */
	b	bad_vector	/* DATA_ABORT */

.section ".text.sdram"
sdram_text:
	nop
	nop
	ret
