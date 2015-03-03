#include <assert.h>
#include <errno.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>

#include "cache.h"
#include "io.h"

#define CACHE_OFFSET_SZ		(1 << ICACHE_OFFSET_BITS)
#define CACHE_OFFSET_MASK	((1 << ICACHE_OFFSET_BITS) - 1)

#define CACHE_INDEX_SZ		((1 << ICACHE_INDEX_BITS) * CACHE_OFFSET_SZ)
#define CACHE_INDEX_SHIFT	ICACHE_OFFSET_BITS
#define CACHE_INDEX_MASK	(((1 << ICACHE_INDEX_BITS) - 1) << ICACHE_OFFSET_BITS)

#define CACHE_TAG_BITS		(32 - (ICACHE_INDEX_BITS + ICACHE_OFFSET_BITS))
#define CACHE_TAG_SHIFT		(ICACHE_OFFSET_BITS + ICACHE_INDEX_BITS)
#define CACHE_TAG_MASK		(((1 << CACHE_TAG_BITS) - 1) << CACHE_TAG_SHIFT)

struct cache_line {
	union {
		uint32_t data32[CACHE_OFFSET_SZ / sizeof(uint32_t)];
		uint16_t data16[CACHE_OFFSET_SZ / sizeof(uint16_t)];
		uint8_t data8[CACHE_OFFSET_SZ / sizeof(uint16_t)];
	};
	unsigned tag:CACHE_TAG_BITS;
	unsigned valid:1;
	unsigned dirty:1;
};

struct cache {
	struct mem_map *mem;
	struct cache_line lines[ICACHE_NUM_WAYS][CACHE_INDEX_SZ];
	unsigned victimsel;
};

struct cache *cache_new(struct mem_map *mem)
{
	struct cache *c = calloc(1, sizeof(*c));

	if (c)
		c->mem = mem;

	return c;
}

static inline uint32_t addr_offs(uint32_t addr)
{
	return addr & CACHE_OFFSET_MASK;
}

static inline uint32_t addr_index(uint32_t addr)
{
	return (addr & CACHE_INDEX_MASK) >> CACHE_INDEX_SHIFT;
}

static inline uint32_t addr_tag(uint32_t addr)
{
	return (addr & CACHE_TAG_MASK) >> CACHE_TAG_SHIFT;
}

void cache_inval_index(struct cache *cache, uint32_t indx)
{
	if (indx <= CACHE_INDEX_SZ) {
		unsigned way;

		for (way = 0; way < ICACHE_NUM_WAYS; ++way) {
			cache->lines[way][indx].valid = 0;
			cache->lines[way][indx].dirty = 0;
		}
	}
}

void cache_inval_all(struct cache *cache)
{
	int i;

	for (i = 0; i < CACHE_INDEX_SZ; ++i) {
		unsigned way;

		for (way = 0; way < ICACHE_NUM_WAYS; ++way) {
			cache->lines[way][i].valid = 0;
			cache->lines[way][i].dirty = 0;
		}
	}
}

static int cache_fill_line(const struct cache *cache, struct cache_line *line,
			   uint32_t addr)
{
	uint32_t tag = addr_tag(addr);
	int rc = 0, br = 0;

	for (br = 0; br < CACHE_OFFSET_SZ; br += sizeof(uint32_t)) {
		rc = mem_map_read(cache->mem, addr + br, 32,
				  &line->data32[br / sizeof(uint32_t)]);
		if (rc)
			break;
	}

	line->valid = !rc;
	line->dirty = 0;
	line->tag = tag;

	return rc;
}

static struct cache_line *cache_find_line(struct cache *cache, uint32_t addr)
{
	unsigned way;

	/* Look for a cache hit. */
	for (way = 0; way < ICACHE_NUM_WAYS; ++way) {
		struct cache_line *line = &cache->lines[way][addr_index(addr)];
		if (line->valid && line->tag == addr_tag(addr))
			return line;
	}

	/* Return the next victim. */
	return &cache->lines[cache->victimsel][addr_index(addr)];
}

int cache_read(struct cache *cache, uint32_t virt, uint32_t phys,
	       unsigned int nr_bits, uint32_t *val)
{
	struct cache_line *line = cache_find_line(cache, virt);
	uint32_t tag = addr_tag(phys);
	uint32_t offs = addr_offs(virt);
	int rc = 0;

	if (!line->valid || tag != line->tag) {
		cache_flush_index(cache, addr_index(virt));

		rc = cache_fill_line(cache, line, phys & ~CACHE_OFFSET_MASK);
		if (rc != 0)
			goto out;
	}

	switch (nr_bits) {
	case 8:
		*val = line->data8[offs];
		break;
	case 16:
		*val = line->data16[offs / sizeof(uint16_t)];
		break;
	case 32:
		*val = line->data32[offs / sizeof(uint32_t)];
		break;
	default:
		return -EIO;
	}

	cache->victimsel = (cache->victimsel + 1) % ICACHE_NUM_WAYS;

out:
	return rc;
}

int cache_write(struct cache *cache, uint32_t virt, uint32_t phys,
		unsigned int nr_bits, uint32_t val)
{
	struct cache_line *line = cache_find_line(cache, virt);
	uint32_t tag = addr_tag(phys);
	uint32_t offs = addr_offs(virt);
	int rc = 0;

	/* No allocate on write. */
	if (!line->valid || tag != line->tag)
		return mem_map_write(cache->mem, phys, nr_bits, val);

	switch (nr_bits) {
	case 8:
		line->data8[offs] = val;
		break;
	case 16:
		line->data16[offs / sizeof(uint16_t)] = val;
		break;
	case 32:
		line->data32[offs / sizeof(uint32_t)] = val;
		break;
	default:
		return -EIO;
	}
	line->dirty = 1;

	cache->victimsel = (cache->victimsel + 1) % ICACHE_NUM_WAYS;

	return rc;
}

int cache_flush_index(struct cache *cache, uint32_t indx)
{
	int rc = 0;
	unsigned int m, way;

	if (indx >= CACHE_INDEX_SZ)
		return 0;

	for (way = 0; way < ICACHE_NUM_WAYS; ++way) {
		uint32_t addr = (cache->lines[way][indx].tag << CACHE_TAG_SHIFT) |
			(indx << CACHE_INDEX_SHIFT);

		if (!cache->lines[way][indx].dirty)
			continue;

		for (m = 0; m < CACHE_OFFSET_SZ / 4; ++m) {
			rc = mem_map_write(cache->mem, addr + m * 4, 32,
					cache->lines[way][indx].data32[m]);
			if (rc)
				return rc;
		}

		cache->lines[way][indx].dirty = 0;
	}

	return 0;
}

int cache_flush_all(struct cache *cache)
{
	int rc = 0, i;

	for (i = 0; i < CACHE_INDEX_SZ; ++i) {
		rc = cache_flush_index(cache, i);
		if (rc)
			break;
	}

	return rc;
}
