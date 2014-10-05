Oldland CPU
===========

[![Build Status](https://travis-ci.org/jamieiles/oldland-cpu.svg?branch=master)](https://travis-ci.org/jamieiles/oldland-cpu)

Oldland is a 32-bit RISC CPU targeted at FPGAs.  It is has a 5 stage pipeline,
16 general purpose registers, instruction+data caches and support for
exceptions including interrupts, data+instruction abort and software
interrupts.  A debug controller allows execution control (run, stop, step),
inspection+modification of registers+memory and breakpoints.

Keynsham is a SoC using Oldland as the core and has a number of peripherals:

 - 32MB SDR SDRAM controller.
 - SPI master with configurable number of chip selects.
 - On-chip bootrom.
 - On-chip memory.
 - Programmable timers.
 - Interrupt controller.
 - UART.

There is a C model along with Icarus and Verilator RTL simulations.  The
Keynsham SoC can be synthesized to run on a Terasic DE0 Nano.  There are ports
of binutils, gcc and u-boot available.

For documentation see the [Oldland CPU site](http://jamieiles.github.io/oldland-cpu/)
