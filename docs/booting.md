---
title: Keynsham SOC booting
layout: default
root: "../"
---

On reset, the Oldland CPU begins fetching from the on-chip bootrom at
0x10000000.  This bootrom uses CS0 on the SPI master to load a second stage
bootloader from an SD card.  The process is roughly:

  - Initialize the SD card at a low clock speed.
  - Read the first sector of the card, asserting that it is an MBR.
  - Find the active boot partition.
  - Mount the boot partition as a FAT filesystem and look for `/boot.elf` and
  load it into memory.
  - Execute the second stage bootloader.

This second stage bootloader would typically be something like u-boot and
could then chain load an operating system such as RTEMS or Linux.
