CROSS_COMPILE ?= oldland-elf-

AS := $(CROSS_COMPILE)as
LD := $(CROSS_COMPILE)ld
OBJCOPY := $(CROSS_COMPILE)objcopy

ifeq ($(SIM),y)
OBJS := sim.o
else
OBJS := bootrom.o
endif

.PHONY:	all clean

all:	bootrom.ihex bootrom.hex

%.o:	%.s
	$(AS) $< -o $@

bootrom:	$(OBJS)
	$(LD) $^ -o $@ -x bootrom.x

%.bin:	%
	$(OBJCOPY) $< $@ -O binary

%.hex:	%
	$(OBJCOPY) $< $@ -O verilog

%.ihex:	%.bin
	../tools/makeramfile/makeramfile $< $@

clean:
	rm -f *.bin *.hex *.o bootrom
