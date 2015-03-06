.include "common.s"

.equ	IDENTITY_VIRT_MAPPING, 0x20000003 /* R|W */
.equ	IDENTITY_PHYS_MAPPING, 0x20000000
.equ	DTLB_STORE_VIRT, 4
.equ	DTLB_STORE_PHYS, 5
.equ	ITLB_STORE_VIRT, 6
.equ	ITLB_STORE_PHYS, 7

	.section ".text.sdram", "ax"
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

	b	end_of_page
complete:
	TESTPOINT TP_USER, 0
	SUCCESS

	.balign 4096
	.skip 4076
end_of_page:
	add	$r8, $r8, 1
	add	$r8, $r8, 1
	add	$r8, $r8, 1
	add	$r8, $r8, 1
	add	$r8, $r8, 1
	/* New page boundary. */
	add	$r8, $r8, 1
	b	complete

failure:
dtlb_miss_handler:
	FAILURE

itlb_miss_handler:
	/* cr3 (ifar) contains the address that was unmapped. */
	gcr	$r0, 3

	/* Get the page index, masking off the offset. */
	mov	$r1, 4095
	xor	$r1, $r1, -1
	and	$r0, $r0, $r1
	or	$r0, $r0, 1 /* R */
	cache	$r0, ITLB_STORE_VIRT
	cache	$r0, ITLB_STORE_PHYS

	/* Restart the faulting instruction. */
	gcr	$r0, 3
	sub	$r0, $r0, 4
	scr	3, $r0

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
