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

	movhi	$r9, %hi(0x0bad1dea)
	orlo	$r9, $r9, %lo(0x0bad1dea)
	movhi	$r10, %hi(0x20000100)
	orlo	$r10, $r10, %lo(0x20000100)
	str32	$r9, [$r10, 0]

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

_test_dtlb_miss:
	movhi	$r0, %hi(0x40000100)
	orlo	$r0, $r0, %lo(0x40000100)
	ldr32	$r11, [$r0, 0]

_test_itlb_miss:
	movhi	$r0, %hi(sdram_text)
	orlo	$r0, $r0, %lo(sdram_text)
	call	$r0
	cmp	$r12, 0x77
	bne	failure
	cmp	$r11, $r9
	bne	failure

	SUCCESS

failure:
	FAILURE

dtlb_miss_handler:
	/*
	 * Install a TLB entry for the faulting address.
	 */
	movhi	$r7, %hi(0x40000000)
	orlo	$r7, $r7, %lo(0x40000000)
	cache	$r7, DTLB_STORE_VIRT
	movhi	$r7, %hi(0x20000000)
	orlo	$r7, $r7, %lo(0x20000000)
	cache	$r7, DTLB_STORE_PHYS

	/* Restart the faulting instruction. */
	gcr     $r8, 3     
	sub     $r8, $r8, 4
	scr     3, $r8     

	rfe

itlb_miss_handler:
	/*
	 * Install a TLB entry for the faulting address.
	 */
	movhi	$r7, %hi(0x20000000)
	orlo	$r7, $r7, %lo(0x20000000)
	cache	$r7, ITLB_STORE_VIRT
	movhi	$r7, %hi(0x20000000)
	orlo	$r7, $r7, %lo(0x20000000)
	cache	$r7, ITLB_STORE_PHYS

	/* Restart the faulting instruction. */
	gcr     $r8, 3     
	sub     $r8, $r8, 4
	scr     3, $r8     

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
	mov	$r12, 0x77
	nop
	nop
	ret
