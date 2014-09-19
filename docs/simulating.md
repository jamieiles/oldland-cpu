---
title: Simulating Oldland CPU
layout: default
root: "../"
---

There are three different simulators for the CPU:

- oldland-sim: an instruction set simulator in C and is not cycle accurate.
- oldland-rtlsim: an Icarus verilog simulation, models events but can be slow.
- oldland-verilatorsim: a Verilator based simulation that runs > 1MHz and is
cycle accurate.

The Icarus simulation is the most accurate and includes vendor models of the
SDRAM whereas the verilator model does not model SDRAM timing or
configuration.

For interactive simulation:

- Run the simulation:  
    `oldland-rtlsim --interactive`
  
- Observe the PTS number.
  
- Load the application binary through the onchip bootrom  
    `./tools/bootterm/bootterm /dev/pts/PTS_NUM binary_file`
  
- Attach minicom to the uart:  
    `minicom -p /dev/pts/PTS_NUM`

To bypass the onchip bootrom for quicker loads:

- Run the simulation:  
    `oldland-rtlsim --interactive --ramfile=path_to_ram_file --bootrom=sim.hex`

- Observe the PTS number.
  
- Attach minicom to the uart:  
    `minicom -p /dev/pts/PTS_NUM`
