#define _GNU_SOURCE

#include <assert.h>
#include <err.h>
#include <errno.h>
#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#include <unistd.h>

#include <sys/mman.h>
#include <sys/stat.h>
#include <sys/types.h>

#include <elf.h>

#include "debugger.h"

struct elf_info {
	int fd;
	const char *path;
	const void *elf;
	const Elf32_Ehdr *ehdr;
	const Elf32_Shdr *shdrs;
	const char *secstrings;
	size_t maplen;
};

static int map_elf(const char *path, struct elf_info *info)
{
	struct stat stat;

	info->fd = open(path, O_RDONLY);
	if (info->fd < 0) {
		warn("failed to open %s for reading", path);
		return -errno;
	}

	if (fstat(info->fd, &stat) < 0) {
		warn("failed to stat %s", path);
		return -errno;
	}

	info->maplen = ((stat.st_size + getpagesize() - 1) / getpagesize()) *
		getpagesize();
	info->elf = mmap(NULL, info->maplen, PROT_READ, MAP_SHARED, info->fd, 0);
	if (info->elf == MAP_FAILED) {
		warn("failed to map %s for reading", path);
		close(info->fd);
		return -errno;
	}

	return 0;
}

static int init_elf(const char *path, struct elf_info *info)
{
	int ret;

	info->path = strdup(path);
	ret = map_elf(path, info);
	if (ret) {
		free((void *)info->path);
		return ret;
	}

	info->ehdr = info->elf;
	info->shdrs = (const void *)info->ehdr + info->ehdr->e_shoff;
	info->secstrings = (const void *)info->ehdr +
		info->shdrs[info->ehdr->e_shstrndx].sh_offset;

	return 0;
}

#define for_each_section(shdr, pos, elf) \
	for ((pos) = 1, (shdr) = &(elf)->shdrs[(pos)]; \
	     (pos) < (elf)->ehdr->e_shnum; \
	     (pos)++, (shdr) = &(elf)->shdrs[(pos)])

static void unmap_elf(const struct elf_info *info)
{
	free((void *)info->path);
	munmap((void *)info->elf, info->maplen);
	close(info->fd);
}

static int load_section(const struct target *target, uint32_t addr,
			const uint8_t *data, size_t len)
{
	int ret;

	while (len-- != 0) {
		uint32_t v = *(data++);

		ret = dbg_write8(target, addr++, v);
		if (ret) {
			warnx("failed to write to %08x", addr);
			break;
		}
	}

	return ret;
}

static const Elf32_Shdr *find_section(const struct elf_info *elf,
				      const char *name)
{
	const Elf32_Shdr *shdr;
	int i;

	for_each_section(shdr, i, elf) {
		const char *n = elf->secstrings + shdr->sh_name;

		if (!strcmp(n, name))
			return shdr;
	}

	return NULL;
}

static void load_testpoints(const struct elf_info *elf,
			    struct testpoint **testpoints,
			    size_t *nr_testpoints)
{
	const Elf32_Shdr *tp_section = find_section(elf, ".testpoints");

	*nr_testpoints = 0;

	if (!tp_section)
		return;

	*testpoints = malloc(tp_section->sh_size);
	if (!*testpoints)
		return;

	memcpy(*testpoints, elf->elf + tp_section->sh_offset,
	       tp_section->sh_size);
	*nr_testpoints = tp_section->sh_size / sizeof(struct testpoint);
}

int load_elf(const struct target *target, const char *path,
	     struct testpoint **testpoints, size_t *nr_testpoints)
{
	struct elf_info elf = {};
	int i, ret;
	const Elf32_Shdr *shdr;

	ret = init_elf(path, &elf);
	if (ret)
		return ret;

	for_each_section(shdr, i, &elf) {
		const char *name = elf.secstrings + shdr->sh_name;

		if (!(shdr->sh_flags & SHF_ALLOC))
			continue;

		ret = load_section(target, (uint32_t)shdr->sh_addr,
				   elf.elf + shdr->sh_offset, shdr->sh_size);
		if (ret) {
			warnx("failed to load section %s to %08x", name,
			      (uint32_t)shdr->sh_addr);
			goto out;
		}
	}

	if (dbg_write_reg(target, PC, (uint32_t)elf.ehdr->e_entry))
		warnx("failed to set PC to entry point %08x",
		      (uint32_t)elf.ehdr->e_entry);

	load_testpoints(&elf, testpoints, nr_testpoints);

out:
	unmap_elf(&elf);

	return ret;
}
