---
title: Oldland TLB
layout: default
root: "../"
---

The TLB is software managed and has a configurable number of entries, pages
are 4KB in size.  The TLB is managed with the new "tlb" instruction to set
physical/virtual mappings.

On a TLB miss, the CPU jumps to the tlb miss handler, and the address of this
handler is stored in (cr5: dtlb miss, cr6: itlb miss).  The address is
physical and the handler is called with the MMU disabled.  Once the handler
has performed the translation and installed a new TLB entry, the fault address
register (cr3) should be fixed up to retry the instruction and an rfe issued
to restart that instruction and re-enable the MMU.  The miss handlers are
stored separately from the exception table as they use physical addresses.

To install a new TLB entry:

	cache	4, $r0 // Latch in the TLB entry.  This is the virtual
		       // address, access permissions etc.
	cache	5, $r1 // Latch in the physical address, this loads the TLB
		       // entry into the TLB.

Installation of the TLB is not complete until both instructions have been
executed and must be executed in that order.  A new operation is added to the
cache instruction to invalidate all TLB entries.

TLB replacement policy is round-robin and the MMU is enabled with the M bit in
the PSR.  Sufficient NOP's should be inserted to clear the pipeline before
enabling the MMU for the first time, re-enabling by rfe will flush the
pipeline first.

When writing a TLB entry, the virtual address format is:

  - \[31:12\]: 20 MSB's of the virtual address to map the page at.
  - \[11:2\]: SBZ.  Reserved for access control bits.
  - \[1]: Page is writable.
  - \[0]: Page is readable.

The physical address format is:

  - \[31:12\]: 20 MSB's of the physical page being mapped.
  - \[11:0\]: SBZ

For ITLB entries the writable bit is ignored.  Note that there is no need for
an executable bit - to make a non-executable page just insert into the ITLB
with the readable bit clear.
