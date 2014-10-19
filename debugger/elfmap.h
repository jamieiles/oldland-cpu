#ifndef __ELFMAP_H__
#define __ELFMAP_H__

#include <stddef.h>

struct elf_info {
	int fd;
	const char *path;
	const void *elf;
	const Elf32_Ehdr *ehdr;
	const Elf32_Shdr *shdrs;
	const Elf32_Phdr *phdrs;
	const char *secstrings;
	size_t maplen;
};

#define for_each_section(shdr, pos, elf) \
	for ((pos) = 1, (shdr) = &(elf)->shdrs[(pos)]; \
	     (pos) < (elf)->ehdr->e_shnum; \
	     (pos)++, (shdr) = &(elf)->shdrs[(pos)])

#define for_each_phdr(phdr, elf) \
	for ((phdr) = (elf)->phdrs; \
	     (phdr) < (elf)->phdrs + (elf)->ehdr->e_phnum; \
	     (phdr)++)

int init_elf(const char *path, struct elf_info *info);
void unmap_elf(const struct elf_info *info);

#endif /* __ELFMAP_H__ */
