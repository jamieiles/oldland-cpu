Oldland CPU
===========

[![Build Status](https://travis-ci.org/jamieiles/oldland-cpu.svg?branch=master)](https://travis-ci.org/jamieiles/oldland-cpu)

Oldland is a 32-bit RISC CPU targeted at FPGAs.  The main features are:

  - 5 stage load/store pipeline.
  - 16 general purpose registers.
  - N-way set-associative blocking instruction/data caches
  - Software managed instruction/data TLBs with 4KB page size.
  - JTAG debug controller for execution control and state
  modification/inspection.
  - Exception table for interrupts, data/instruction aborts, illegal
  instruction and software interrupts along with separate ITLB/DTLB miss
  handlers.
  - User and supervisor modes.

Keynsham is a SoC using Oldland as the core and has a number of peripherals:

 - 32MB SDR SDRAM controller.
 - SPI master with configurable number of chip selects.
 - On-chip bootrom.
 - On-chip memory.
 - Programmable timers.
 - Interrupt controller.
 - UART.
 - SPI master.

There is a C model along with Icarus and Verilator RTL simulations.  The
Keynsham SoC can be synthesized to run on a Terasic DE0 Nano.  There are ports
of binutils, gcc and u-boot available.

For documentation see the [Oldland CPU site](http://jamieiles.github.io/oldland-cpu/)
