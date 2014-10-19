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

#include "elfmap.h"

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

int init_elf(const char *path, struct elf_info *info)
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
	info->phdrs = (const void *)info->ehdr + info->ehdr->e_phoff;
	info->secstrings = (const void *)info->ehdr +
		info->shdrs[info->ehdr->e_shstrndx].sh_offset;

	return 0;
}

void unmap_elf(const struct elf_info *info)
{
	free((void *)info->path);
	munmap((void *)info->elf, info->maplen);
	close(info->fd);
}
