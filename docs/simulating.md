---
title: Simulating Oldland CPU
layout: default
root: "../"
---

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
