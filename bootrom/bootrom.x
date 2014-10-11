OUTPUT_FORMAT("elf32-oldland", "elf32-oldland",
	      "elf32-oldland")
OUTPUT_ARCH(oldland)
ENTRY(_start)

MEMORY {
	rom : ORIGIN = 0x10000000, LENGTH = 16K
	sdram : ORIGIN = 0x20C00000, LENGTH = 1M
}

PHDRS {
	headers PT_PHDR FILEHDR PHDRS ;
	text PT_LOAD ;
	data PT_LOAD ;
	bss PT_LOAD ;
}

SECTIONS {
	.text 0x10000000 : AT(0x00000000) {
		*(.text);
		*(.text.*);
	} > rom :text

	.rodata	: {
		*(.rodata);
		*(.rodata.*);
		. = ALIGN(4);
	} > rom :data

	.bss : {
		_bss_start = . ;
		*(.bss);
		*(COMMON);
		_bss_end = . ;
	} > sdram :bss

	/DISCARD/ : {
		*(.comment);
		*(.debug*);
	}
}
