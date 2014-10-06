---
title: Oldland Architecture Definition
layout: default
root: "../"
---

Oldland CPU
===========

Architecture
------------

- 13x32-bit GPR's.
- 1x32-bit frame pointer, addressable as FP
- 1x32-bit link register, addressable as LR.
- 1x32-bit stack pointer, addressable as SP.
- 1x32-bit status register:
  - Interrupt enable flag
  - Negative flag
  - Overflow flag
  - Carry flag
  - Zero flag

Everything is little endian.

Arithmetic/bitwise instructions:

  - ADD, SUB,
  - LSL, LSR, ORR, AND, XOR, BIC
  - Rd := Ra OP Rb or:
  - Rd := Ra OP #imm
  - CMP Ra, Rb

Branch instructions:

  - B #offs := PC += #offs
  - BEQ #offs := if Z: PC += #offs
  - BNE #offs := if Z: PC += #offs
  - BGT #offs := if !Z: PC += #offs
  - CALL #offs # Like branch, but stores the return address in R6.
  - RET # return from CALL

Load/Store instructions:

  - LDR Rd, Ra, #idx := Rd = M[Ra + idx]  
    e.g. LDR R1, [R2, #0x20] means load the contents of M[R2 + 0x20] into R1
  - STR Ra, #idx, Rb := M[Ra + idx] = Rb  
  - LDR16, LDR8, STR16, STR8 : 8 + 16 bit versions.   
    e.g. STR R1, [R2, #0x20] means store the contents of R1 into M[R2 + 0x20]
  - MOVHI Rd, #imm: Rd[31:16] := imm

Example assembly:

{% highlight asm %}
entry:
	add		$r0, r0, #1
	ldr		$r1, dataval
	movhi		$r2, $hi(vtable)
	add		$r2, r2, $lo(vtable)
	call		0x100
	call		myfunc
    
dataval:
	.word		0xdeadbeef
    
myfunc:
	str8		$r2, [$r0, 0x0]
	str		$r1, [$r0, 0x4]
	ret
{% endhighlight %}

ENCODING
--------

For ALU operations, if R is set then rd := ra OP Rb else rd := ra OP I

For branch operations, if R is set then PC := Ra else PC += I

For load, if R, Rd := M[Ra + I] else Rd := M[PC + I]

For store, if R, M[Ra + I] := rb, else M[PC + I] := rb

Encoding:

		31 30 29 28 27 26 25 24 23 22 21 20 19 18 17 16 15 14 13 12 11 10 09 08 07 06 05 04 03 02 01 00
	
	ADD	 0  0  0  0  0  0  R  I  I  I  I  I  I  I  I  I  I  I  I  I ra ra ra ra rb rb rb rb rd rd rd rd
	ADDC	 0  0  0  0  0  1  R  I  I  I  I  I  I  I  I  I  I  I  I  I ra ra ra ra rb rb rb rb rd rd rd rd
	SUB	 0  0  0  0  1  0  R  I  I  I  I  I  I  I  I  I  I  I  I  I ra ra ra ra rb rb rb rb rd rd rd rd
	SUBC	 0  0  0  0  1  1  R  I  I  I  I  I  I  I  I  I  I  I  I  I ra ra ra ra rb rb rb rb rd rd rd rd
	LSL	 0  0  0  1  0  0  R  I  I  I  I  I  I  I  I  I  I  I  I  I ra ra ra ra rb rb rb rb rd rd rd rd
	LSR	 0  0  0  1  0  1  R  I  I  I  I  I  I  I  I  I  I  I  I  I ra ra ra ra rb rb rb rb rd rd rd rd
	AND	 0  0  0  1  1  0  R  I  I  I  I  I  I  I  I  I  I  I  I  I ra ra ra ra rb rb rb rb rd rd rd rd
	XOR	 0  0  0  1  1  1  R  I  I  I  I  I  I  I  I  I  I  I  I  I ra ra ra ra rb rb rb rb rd rd rd rd
	BIC	 0  0  1  0  0  0  R  0  0  0  0  0  0  0  0  0  0  I  I  0 ra ra ra ra rb rb rb rb rd rd rd rd
	BST	 0  0  1  0  0  1  R  0  0  0  0  0  0  0  0  0  0  I  I  0 ra ra ra ra rb rb rb rb rd rd rd rd
	OR 	 0  0  1  0  1  0  R  I  I  I  I  I  I  I  I  I  I  I  I  I ra ra ra ra rb rb rb rb rd rd rd rd
	CMP	 0  0  1  1  0  0  R  I  I  I  I  I  I  I  I  I  I  I  I  I ra ra ra ra rb rb rb rb  x  x  x  x
	ASR 	 0  0  1  1  1  0  R  I  I  I  I  I  I  I  I  I  I  I  I  I ra ra ra ra rb rb rb rb rd rd rd rd
	MOV 	 0  0  1  1  1  1  R  I  I  I  I  I  I  I  I  I  I  I  I  I  x  x  x  x rb rb rb rb rd rd rd rd
	
	CALL	 0  1  0  0  0  0  R  x  I  I  I  I  I  I  I  I  I  I  I  I  I  I  I  I  I  I  I  I IR IR IR IR
	RET	 0  1  0  0  0  1  1  x  x  x  x  x  x  x  x  x  x  x  x  x  1  1  1  0  x  x  x  x  x  x  x  x
	RFE	 0  1  0  0  1  0  0  x  x  x  x  x  x  x  x  x  x  x  x  x  x  x  x  x  x  x  x  x  x  x  x  x
	B	 0  1  0  1  0  0  R  x  I  I  I  I  I  I  I  I  I  I  I  I  I  I  I  I  I  I  I  I IR IR IR IR
	BNE	 0  1  0  1  0  1  R  x  I  I  I  I  I  I  I  I  I  I  I  I  I  I  I  I  I  I  I  I IR IR IR IR
	BEQ	 0  1  0  1  1  0  R  x  I  I  I  I  I  I  I  I  I  I  I  I  I  I  I  I  I  I  I  I IR IR IR IR
	BGT	 0  1  0  1  1  1  R  x  I  I  I  I  I  I  I  I  I  I  I  I  I  I  I  I  I  I  I  I IR IR IR IR
	BLT	 0  1  1  0  0  0  R  x  I  I  I  I  I  I  I  I  I  I  I  I  I  I  I  I  I  I  I  I IR IR IR IR
	BGTS	 0  1  1  0  0  1  R  x  I  I  I  I  I  I  I  I  I  I  I  I  I  I  I  I  I  I  I  I IR IR IR IR
	BLTS	 0  1  1  0  1  0  R  x  I  I  I  I  I  I  I  I  I  I  I  I  I  I  I  I  I  I  I  I IR IR IR IR

	BGTE	 0  1  1  1  0  0  R  x  I  I  I  I  I  I  I  I  I  I  I  I  I  I  I  I  I  I  I  I IR IR IR IR
	BGTES	 0  1  1  1  0  1  R  x  I  I  I  I  I  I  I  I  I  I  I  I  I  I  I  I  I  I  I  I IR IR IR IR
	BLTE	 0  1  1  1  1  0  R  x  I  I  I  I  I  I  I  I  I  I  I  I  I  I  I  I  I  I  I  I IR IR IR IR
	BLTES	 0  1  1  0  1  1  R  x  I  I  I  I  I  I  I  I  I  I  I  I  I  I  I  I  I  I  I  I IR IR IR IR

	SWI	 0  1  1  1  1  1  0  I  I  I  I  I  I  I  I  I  I  I  I  I  x  x  x  x  x  x  x  x  x  x  x  x
	
	LDR	 1  0  0  0  0  0  R  I  I  I  I  I  I  I  I  I  I  I  I  I ra ra ra ra  x  x  x  x rd rd rd rd
	LDR16	 1  0  0  0  0  1  R  I  I  I  I  I  I  I  I  I  I  I  I  I ra ra ra ra  x  x  x  x rd rd rd rd
	LDR8	 1  0  0  0  1  0  R  I  I  I  I  I  I  I  I  I  I  I  I  I ra ra ra ra  x  x  x  x rd rd rd rd
	
	STR	 1  0  0  1  0  0  R  I  I  I  I  I  I  I  I  I  I  I  I  I ra ra ra ra rb rb rb rb  x  x  x  x
	STR16	 1  0  0  1  0  1  R  I  I  I  I  I  I  I  I  I  I  I  I  I ra ra ra ra rb rb rb rb  x  x  x  x
	STR8	 1  0  0  1  1  0  R  I  I  I  I  I  I  I  I  I  I  I  I  I ra ra ra ra rb rb rb rb  x  x  x  x

	CACHE	 1  0  1  1  1  1  1  I  I  I  I  I  I  I  I  I  I  I  I  I ra ra ra ra  x  x  x  x  x  x  x  x
	
	BKP	 1  1  0  0  0  0  0  0  0  0  0  0  0  0  0  0  0  0  0  0  x  x  x  x  x  x  x  x  x  x  x  x
	GCR	 1  1  0  0  0  1  0  I  I  I  I  I  I  I  I  I  I  I  I  I  x  x  x  x  x  x  x  x rd rd rd rd
	SCR	 1  1  0  0  1  0  0  I  I  I  I  I  I  I  I  I  I  I  I  I ra ra ra ra  x  x  x  x  x  x  x  x
	MOVHI	 1  1  1  0  1  1  I  I  I  I  I  I  I  I  I  I  I  I  I  I  I  I  0  x  x  x  x  x rd rd rd rd
	ORLO	 1  1  1  1  0  1  I  I  I  I  I  I  I  I  I  I  I  I  I  I  I  I  0  x rb rb rb rb rd rd rd rd
	CPUID	 1  1  0  1  1  1  0  I  I  I  I  I  I  I  I  I  I  I  I  I  x  x  x  x  x  x  x  x rd rd rd rd
	NOP	 1  1  1  1  1  1  x  x  x  x  x  x  x  x  x  x  x  x  x  x  x  x  x  x  x  x  x  x  x  x  x  x

RELOCATIONS
-----------

- R_OLDLAND_NONE:
    - NOP
- R_OLDLAND_32:
    - 32-bit absolute relocation:
- R_OLDLAND_PC24:
    - 24-bit PC-relative relocation for branches.
- R_OLDLAND_PC16:
    - 16-bit PC-relative relocation for load/store.
- R_OLDLAND_HI16:
    - 16-bit absolute relocation for MOVHI.
- R_OLDLAND_LO16:
    - 16-bit absolute relocation for ADD/OR.

ALU operations
--------------

- ra OP rb
- ra OP imm13
- pc OP imm24
- pc OP imm13
- pc OP rb

Stalling
--------

Branch target doesn't get resolved until execute stage.  Stall until PC is
updated with branch target.

Memory accesses can take a variable number of cycles (cache misses/peripherals
etc).  Stall until access completed.

Exception Handling
------------------

Exception handlers are defined in a table of jumps to handlers:

0x00:	reset
0x04:	illegal instruction
0x08:	software interrupt
0x0c:	hardware interrupt
0x10:	instruction fetch abort
0x14:	data abort

The table must be aligned to a 64 byte boundary.

The address of the table is stored in control register 0, so to set the table:

	movhi	$r0, %hi(ex_table)
	orlo	$r0, $r0, %lo(ex_table)
	scr	0, $r0

On exception entry the CPU enters the exception handling mode and stores the
contents of the current mode PSR into the saved PSR control register.  The
fault address is stored in cr4 and the cpu jumps to the correct exception
handler.

To return from the exception the RFE instruction restores the saved PSR from
the saved registers and sets the PC to the faulting address (which can be
modified in the exception handler).

$sp is banked between user/supervisor mode to make handling of exceptions more
convenient and there are a pair of instructions for reading/writing the
usermode $sp, only from supervisor mode.  There are only 2 processor modes.

IRQ entry:

  - discard instructions in fetch and decode stages
  - move current $sp into saved_sp
  - move current psr into saved_psr
  - store pc_plus_4 at execute stage into fault_address
  - disable irqs in psr
  - set branch enable and branch destination to the irq entry

RFE implementation:

  - discard instructions in fetch and decode stages.
  - move saved sp into $sp
  - moved saved_psr into psr
  - move fault_address into pc (handler should have adjusted it).

Control registers:

- cr0:	exception table base address
	- \[31:6\]: exception table base address[31:6]
	- \[5:0\]:  reserved, SBZ

- cr1:	PSR
	- \[31:4\]: reserved, SBZ
	- \[5:5\]:  user mode
	- \[4:4\]:  irqs enabled
	- \[3:3\]:  negative flag
	- \[2:2\]:  overflow flag
	- \[1:1\]:  carry flag
	- \[0:0\]:  zero flag
- cr2:	saved PSR
- cr3:	fault address register
- cr4:	data fault address

CPUID registers
---------------

The CPUID registers provide a mechanism for software to discover hardware
features:

- 0: CPU version
     - \[31:16\]:	Vendor
     - \[15:0\]:	Model
- 1: CPU core speed
     - \[31:0\]	core speed (Hz)
- 2: Instruction set features
     - \[31:0\]:	SBZ
- 3: Instruction cache feature register
     - \[31:24\]:	SBZ
     - \[23:8\]:	number of cache lines
     - \[7:0\]:	words per cache line
- 4: Data cache feature register
     - \[31:24\]:	SBZ
     - \[23:8\]:	number of cache lines
     - \[7:0\]:	words per cache line
