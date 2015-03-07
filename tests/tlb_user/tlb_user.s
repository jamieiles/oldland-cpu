.include "common.s"

.equ	DTLB_STORE_VIRT, 4
.equ	DTLB_STORE_PHYS, 5
.equ	ITLB_STORE_VIRT, 6
.equ	ITLB_STORE_PHYS, 7

.equ	S_R, 0x1
.equ	S_W, 0x2
.equ	S_RW, 0x3
.equ	U_R, 0x4
.equ	U_W, 0x8
.equ	U_RW, 0xc

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

	/* First RAM page is read/write for user + supervisor. */
	map_instruction_page 0x00000000, (U_RW | S_RW)
	map_data_page 0x00000000, (U_RW | S_RW)

	/* First SDRAM page is read/write supervisor. */
	map_instruction_page 0x20000000, S_RW
	map_data_page 0x20000000, S_RW

	/* Second SDRAM page is read/write user. */
	map_instruction_page 0x20001000, U_RW
	map_data_page 0x20001000, U_RW

	/* Enable MMU. */
	gcr	$r0, 1
	or	$r0, $r0, 0xe0
	scr	1, $r0

	/*
	 * Accesses to pages that are marked user only should fault in
	 * supervisor mode.
	 */
	movhi	$r10, %hi(0x20001000)
	orlo	$r10, $r10, %lo(0x20001000)
	ldr32	$r0, [$r10, 0]
	TESTPOINT TP_USER, 0
	str32	$r0, [$r10, 0]
	TESTPOINT TP_USER, 1

	/*
	 * Accesses to pages that are marked supervisor only should be fine in
	 * supervisor mode.
	 */
	movhi	$r11, %hi(0x20000000)
	orlo	$r11, $r11, %lo(0x20000000)
	ldr32	$r0, [$r11, 0]
	TESTPOINT TP_USER, 2
	str32	$r0, [$r11, 0]
	TESTPOINT TP_USER, 3

	/*
	 * Switch to user mode.
	 */
	gcr	$r0, 1
	or	$r0, $r0, 0x100
	scr	1, $r0

	/*
	 * Accesses to pages marked user only should work in user mode.
	 */
	ldr32	$r0, [$r10, 0]
	TESTPOINT TP_USER, 4
	str32	$r0, [$r10, 0]
	TESTPOINT TP_USER, 5

	/*
	 * Accesses to supervisor only pages should fault when in user mode.
	 */
	ldr32	$r0, [$r11, 0]
	TESTPOINT TP_USER, 6
	str32	$r0, [$r11, 0]
	TESTPOINT TP_USER, 7

	SUCCESS

dtlb_miss_handler:
itlb_miss_handler:
	FAILURE

data_abort:
	TESTPOINT TP_USER, 0x100
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
	b	data_abort	/* DATA_ABORT */
