.PHONY:	all keynsham.vvp clean

all:	keynsham.vvp

keynsham.vvp:	vpi_uart.o vpi_debug_stub.o
	iverilog -c oldland.cf -o keynsham.vvp

%.o:	%.c
	iverilog-vpi $<

clean:
	rm -f *.o *.vvp *.vpi
