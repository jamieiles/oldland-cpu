OUTPUT_FORMAT("elf32-oldland", "elf32-oldland",
	      "elf32-oldland")
OUTPUT_ARCH(oldland)
ENTRY(_start)

PHDRS {
	headers PT_PHDR FILEHDR PHDRS ;
	sdramseg PT_LOAD ;
	ramseg PT_LOAD ;
}

MEMORY {
	ram : ORIGIN = 0x00000000, LENGTH = 4K
	sdram : ORIGIN = 0x20000000, LENGTH = 32M
}

SECTIONS {
	.text.sdram : {
		*.text.sdram;
	} > sdram : sdramseg

	.rodata : {
		*.rodata.sdram;
	} > sdram : sdramseg

	.text : {
		*.text;
	} > ram : ramseg

	.rodata	: {
		*.rodata;
		. = ALIGN(4);
	} > ram : ramseg
}
