---
title: Oldland Memory Hierarchy
layout: default
root: "../"
---

Oldland Memory Hierarchy
========================

CPU core has 2 memory busses:
  - 32 bit read-only word addressed instruction bus.
  - 32 bit read/write word addressed data bus with byte enables.

The instruction bus feeds to the instruction cache which is configurable size.
There are inputs to invalidate the entire cache or an address range.  The
cache is physically indexed and physically tagged if the MMU is enabled,
otherwise physically indexed.

Peripherals on the instruction bus are:
  - Onchip bootrom.
  - SDRAM.
  - Onchip memory.

The data cache is physically indexed and physically tagged.  Allocation policy
is allocate on read.  The cache is write-back and write-misses go through a
write buffer.

Each peripheral indicates the cacheability for the entirety of the peripherals
address space.  Non-cacheable peripherals will never have data cached
regardless of any page table settings (though page tables can be used to
control read/write access).

Instruction cache is enabled with the C bit of the PSR, data cache is enabled
with the D bit of the PSR.

Maintenance Instructions
------------------------

Instruction cache:

- `I_INV	index`

Data cache:

- `D_INV	index`
  Invalidate cache line for index.
- `D_FLUSH	index`
  Flush cache line for index.
- `DMB`
  Flush the write buffer for coherence.

All maintenance instructions are encoded into a single cache instruction:

  `cache	op, $rn`

For instructions that don't take a parameter the $rn register should be set to
0.

Cache tags + indexes
--------------------

Cache lines are 32 bytes, so 5 bits for byte offset, cache line is word
indexed so only 3 bits for the real offset.  For a cache of N bytes we have
N/32 indexes so $clog2(N/32) bits.

8KB cache:

  - 19 bits tag.
  - 8 bits index.
  - 5 bits offset.

Reset
-----

On reset, all cache lines are clean + invalid.

Debug
-----

For debugging, a new operation CACHE_SYNC flushes the data cache and
invalidates the entire instruction cache and should be used after memory
writes.
