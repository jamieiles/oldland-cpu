OUTPUT_FORMAT("elf32-oldland", "elf32-oldland",
	      "elf32-oldland")
OUTPUT_ARCH(oldland)
ENTRY(_start)

MEMORY {
	rom : ORIGIN = 0x00000000, LENGTH = 4K
	sdram : ORIGIN = 0x20000000, LENGTH = 32M
}

SECTIONS {
	.text.sdram : {
		*.text.sdram;
	} > sdram

	.rodata : {
		*.rodata.sdram;
	} > sdram

	.text : {
		*.text;
	} > rom

	.rodata	: {
		*.rodata;
		. = ALIGN(4);
	} > rom
}
