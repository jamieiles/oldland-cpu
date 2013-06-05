#define DEBUG

#include <assert.h>
#include <errno.h>
#include <fcntl.h>
#include <stdio.h>
#include <unistd.h>

#include <sys/mman.h>

#include "internal.h"
#include "io.h"

static int ram_write(unsigned int offs, uint32_t val, size_t nr_bits,
		     void *priv)
{
	switch (nr_bits) {
	case 8:
		*(uint8_t *)(priv + offs) = val & 0xff;
		break;
	case 16:
		*(uint16_t *)(priv + offs) = val & 0xffff;
		break;
	case 32:
		*(uint32_t *)(priv + offs) = val;
		break;
	default:
		return -EIO;
	}

	return 0;
}

static int ram_read(unsigned int offs, uint32_t *val, size_t nr_bits,
		    void *priv)
{
	switch (nr_bits) {
	case 8:
		*val = *(uint8_t *)(priv + offs) & 0xff;
		break;
	case 16:
		*val = *(uint16_t *)(priv + offs) & 0xffff;
		break;
	case 32:
		*val = *(uint32_t *)(priv + offs);
		break;
	default:
		return -EIO;
	}

	return 0;
}

static const struct io_ops ram_io_ops = {
	.write = ram_write,
	.read = ram_read,
};

static int rom_write(unsigned int offs, uint32_t val, size_t nr_bits,
		     void *priv)
{
	return -EFAULT;
}

static const struct io_ops rom_io_ops = {
	.write = rom_write,
	.read = ram_read,
};

int ram_init(struct mem_map *mem, physaddr_t base, size_t len,
	     const char *init_contents)
{
	struct region *r;
	void *ram;

	assert(mem != NULL);

	ram = mmap(NULL, len, PROT_READ | PROT_WRITE,
		   MAP_PRIVATE | MAP_ANONYMOUS, -1, 0);
	assert(ram != MAP_FAILED);
	r = mem_map_region_add(mem, base, len, &ram_io_ops, ram);
	assert(r != NULL);

	if (init_contents) {
		ssize_t br;
		int fd = open(init_contents, O_RDONLY);
		assert(fd >= 0);

		br = read(fd, ram, len);
		assert(br >= 0);
		debug("read %zd bytes into RAM @%08x from %s\n", br, base,
		      init_contents);
		close(fd);
	}

	return 0;
}


int rom_init(struct mem_map *mem, physaddr_t base, size_t len,
	     const char *filename)
{
	void *rom;
	struct region *r;
	int fd = open(filename, O_RDONLY);

	assert(fd >= 0);
	rom = mmap(NULL, len, PROT_READ, MAP_PRIVATE, fd, 0);
	assert(rom != MAP_FAILED);
	r = mem_map_region_add(mem, base, len, &rom_io_ops, rom);
	assert(r != NULL);

	return 0;
}

static int sdram_ctrl_write(unsigned int offs, uint32_t val, size_t nr_bits,
			    void *priv)
{
	return 0;
}

static int sdram_ctrl_read(unsigned int offs, uint32_t *val, size_t nr_bits,
			   void *priv)
{
	*val = 1;

	return 0;
}

static const struct io_ops sdram_ctrl_ops = {
	.read = sdram_ctrl_read,
	.write = sdram_ctrl_write,
};

int sdram_ctrl_init(struct mem_map *mem, physaddr_t base, size_t len)
{
	struct region *r = mem_map_region_add(mem, base, len, &sdram_ctrl_ops,
					      NULL);
	assert(r != NULL);

	return 0;
}
