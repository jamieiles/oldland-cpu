.PHONY:	all keynsham.vvp clean

all:	keynsham.vvp

keynsham.vvp:	vpi_uart.o
	iverilog -c oldland.cf -o keynsham.vvp

vpi_uart.o:	vpi_uart.c
	iverilog-vpi $<

clean:
	rm -f *.o *.vvp *.vpi
