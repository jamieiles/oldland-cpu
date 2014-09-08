---
title: Oldland SPI Master
layout: default
root: "../"
---

Oldland SPI Master
==================

Oldland has an SPI master with internal SRAM to reduce wait states when
transferring multiple bytes of data.  There are multiple chip selects
supported and the command is programmed into I/O registers before initiating
the transfer.

Only SPI mode 0 transfers are currently supported.

The transfer buffer may only be accessed with byte accesses.

Registers
---------

Control:

 - \[9\]: loopback enable (data is inverted).
 - \[8:0\]: clock divider, must be a power of two.

CS enable:

 - \[1\]: CS1 enable
 - \[0\]: CS0 enable

Transfer control:

 - \[17\]: bus busy
 - \[16\]: transfer go
 - \[15:13\]: reserved
 - \[12:0\]: transfer octets

Programming
-----------

To perform a transfer:

  1. select the correct divider to give the desired clock rate.
  2. write the bytes to be transmitted into the memory buffer.
  3. write the transfer length into the transfer control register.
  4. set the correct chip select in the chip select control register.
  5. write a 1 to the transfer go bit in the transfer control register.
  6. poll the bus busy bit.
  7. copy the bytes from the buffer into application memory.

The sequencer overwrites the tx bytes in the buffer with the rx bytes on
reception.
