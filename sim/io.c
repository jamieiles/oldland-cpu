/*
 * CPU simulator I/O access.
 *
 * This works like a simple MMU so we can sparsely populate an address space
 * with different I/O types from memory to memory-mapped I/O devices.
 *
 * Copyright 2012, Jamie Iles <jamie@jamieiles.com>
 *
 * Licensed under the GPLv2.
 */
#include <assert.h>
#include <errno.h>
#include <stdint.h>
#include <stdlib.h>

#include "io.h"

#define NR_SUPERSECT_BITS	10
#define SUPERSECT_SHIFT		22
#define SUPERSECT_MASK		(((1 << NR_SUPERSECT_BITS) - 1) << \
				 SUPERSECT_SHIFT)

#define NR_SECT_BITS		10
#define SECT_SHIFT		12
#define SECT_MASK		(((1 << NR_SECT_BITS) - 1) << SECT_SHIFT)
#define PAGE_MASK		(PAGE_SIZE - 1)

struct region {
	physaddr_t base;
	void *priv;
	int (*read)(unsigned int offs, uint32_t *val, size_t nr_bits,
		    void *priv);
	int (*write)(unsigned int offs, uint32_t val, size_t nr_bits,
		     void *priv);
};

static inline unsigned int supersect_idx(physaddr_t p)
{
	return (p & SUPERSECT_MASK) >> SUPERSECT_SHIFT;
}

static inline unsigned int sect_idx(physaddr_t p)
{
	return (p & SECT_MASK) >> SECT_SHIFT;
}

struct supersect {
	struct region *regions[1 << NR_SECT_BITS];
};

struct mem_map {
	struct supersect *supersects[1 << NR_SUPERSECT_BITS];
};

struct mem_map *mem_map_new(void)
{
	return calloc(1, sizeof(struct mem_map));
}

static struct region *mem_map_lookup(struct mem_map *map, physaddr_t addr)
{
	unsigned int idx = supersect_idx(addr);
	struct supersect *ss;

	if (!map->supersects[idx])
		return NULL;

	ss = map->supersects[idx];
	idx = sect_idx(addr);
	if (!ss->regions[idx])
		return NULL;

	return ss->regions[idx];
}

static struct supersect *fetch_or_create_supersect(struct mem_map *map,
						   unsigned int idx)
{
	if (!map->supersects[idx]) {
		map->supersects[idx] =
			calloc(1, sizeof(*map->supersects[idx]));
		assert(map->supersects[idx] != NULL);
	}

	return map->supersects[idx];
}

static struct region *insert_region(struct supersect *ss, unsigned int idx,
				    struct region *r)
{
	if (!ss->regions[idx]) {
		ss->regions[idx] = r;
		return r;
	}

	return NULL;
}

struct region *mem_map_region_add(struct mem_map *map, physaddr_t base,
				  size_t len, const struct io_ops *ops,
				  void *priv)
{
	struct region *r = calloc(1, sizeof(*r));
	
	assert(r != NULL);
	assert(base % PAGE_SIZE == 0);
	assert(len % PAGE_SIZE == 0);

	r->base = base;
	r->priv = priv;
	r->read = ops->read;
	r->write = ops->write;

	while (len > 0) {
		struct supersect *ss =
			fetch_or_create_supersect(map, supersect_idx(base));
		physaddr_t ss_end = (base & SUPERSECT_MASK) | ~SUPERSECT_MASK;
		while (len > 0 && base < ss_end) {
			struct region *new = insert_region(ss, sect_idx(base),
							   r);
			if (!new)
				return NULL;
			len -= PAGE_SIZE;
			base += PAGE_SIZE;
		}
	}

	return r;
}

int mem_map_write(struct mem_map *map, physaddr_t addr, unsigned int nr_bits,
		  uint32_t val)
{
	struct region *r;

	if (addr & ((nr_bits / 8) - 1))
		return -EIO;

	r = mem_map_lookup(map, addr);
	if (!r)
		return -EFAULT;

	return r->write(addr - r->base, val, nr_bits, r->priv);
}

int mem_map_read(struct mem_map *map, physaddr_t addr, unsigned int nr_bits,
		 uint32_t *val)
{
	struct region *r;

	if (addr & ((nr_bits / 8) - 1))
		return -EIO;

	r = mem_map_lookup(map, addr);
	if (!r)
		return -EFAULT;

	return r->read(addr - r->base, val, nr_bits, r->priv);
}
