#ifndef __LOADSYMS_H__
#define __LOADSYMS_H__

#include <stddef.h>

struct symbol {
	const char *name;
	unsigned long value;
};

struct symtab {
	size_t nr_syms;
	struct symbol syms[];
};

struct symtab *load_symbols(const char *path);
void free_symbols(struct symtab *symtab);

#endif /* __LOADSYMS_H__ */
