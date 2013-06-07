CROSS_COMPILE ?= oldland-elf-

AS := $(CROSS_COMPILE)as
LD := $(CROSS_COMPILE)ld
OBJCOPY := $(CROSS_COMPILE)objcopy

OBJS := bootrom.o

.PHONY:	all clean

all:	bootrom.hex

%.o:	%.s
	$(AS) $< -o $@

bootrom:	$(OBJS)
	$(LD) $^ -o $@ -x bootrom.x

%.bin:	%
	$(OBJCOPY) $< $@ -O binary

%.hex:	%.bin
	../tools/makeramfile/makeramfile $< $@

clean:
	rm -f *.bin *.hex *.o bootrom
