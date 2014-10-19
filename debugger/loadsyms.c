#include <assert.h>
#include <elf.h>
#include <errno.h>
#include <string.h>
#include <stdlib.h>
#include <stdio.h>

#include "elfmap.h"
#include "loadsyms.h"

static int find_elf_symtab(const struct elf_info *elf,
			   const Elf32_Sym **syms, size_t *nr_syms)
{
	const Elf32_Shdr *shdr;
	int pos;

	for_each_section(shdr, pos, elf) {
		if (!strcmp(elf->secstrings + shdr->sh_name, ".symtab")) {
			*syms = (const void *)elf->elf + shdr->sh_offset;
			*nr_syms = shdr->sh_size / sizeof(Elf32_Sym);

			return 0;
		}
	}

	return -ENOENT;
}

const char *find_elf_strtab(const struct elf_info *elf)
{
	const Elf32_Shdr *shdr;
	int pos;

	for_each_section(shdr, pos, elf)
		if (!strcmp(elf->secstrings + shdr->sh_name, ".strtab"))
			return (const char *)elf->elf + shdr->sh_offset;

	return NULL;
}

struct symtab *load_symbols(const char *path)
{
	struct elf_info elf;
	struct symtab *symtab = NULL;
	const Elf32_Sym *elfsyms = NULL;
	size_t nr_elfsyms;
	const char *strtab;
	unsigned m;

	if (init_elf(path, &elf))
		return NULL;

	if (find_elf_symtab(&elf, &elfsyms, &nr_elfsyms))
		goto out;
	strtab = find_elf_strtab(&elf);
	if (!strtab)
		goto out;

	symtab = malloc(sizeof(*symtab) + nr_elfsyms * sizeof(struct symbol));
	if (!symtab)
		goto out;

	symtab->nr_syms = nr_elfsyms;
	for (m = 0; m < nr_elfsyms; ++m) {
		symtab->syms[m].value = elfsyms[m].st_value;
		symtab->syms[m].name = strdup(strtab + elfsyms[m].st_name);
		assert(symtab->syms[m].name != NULL);
	}

out:
	unmap_elf(&elf);

	return symtab;
}

void free_symbols(struct symtab *symtab)
{
	free(symtab);
}
