#include <assert.h>
#include <errno.h>
#include <stdint.h>
#include <stdlib.h>

#include "io.h"

#define CACHE_OFFSET_BITS	5
#define CACHE_OFFSET_SZ		(1 << CACHE_OFFSET_BITS)
#define CACHE_OFFSET_MASK	((1 << CACHE_OFFSET_BITS) - 1)

#define CACHE_INDEX_BITS	8
#define CACHE_INDEX_SZ		((1 << CACHE_INDEX_BITS) * CACHE_OFFSET_SZ)
#define CACHE_INDEX_SHIFT	CACHE_OFFSET_BITS
#define CACHE_INDEX_MASK	(((1 << CACHE_INDEX_BITS) - 1) << CACHE_OFFSET_BITS)

#define CACHE_TAG_BITS		(32 - CACHE_INDEX_BITS - CACHE_OFFSET_BITS)
#define CACHE_TAG_SHIFT		(CACHE_OFFSET_BITS + CACHE_INDEX_BITS)
#define CACHE_TAG_MASK		(((1 << CACHE_TAG_SHIFT) - 1) << CACHE_TAG_SHIFT)

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
	struct cache_line lines[CACHE_INDEX_SZ];
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
	assert(indx < CACHE_INDEX_SZ);
	cache->lines[indx].valid = 0;
}

void cache_inval_all(struct cache *cache)
{
	int i;

	for (i = 0; i < CACHE_INDEX_SZ; ++i)
		cache->lines[i].valid = 0;
}

static int cache_fill_line(const struct cache *cache, struct cache_line *line,
			   uint32_t addr)
{
	uint32_t tag = addr_tag(addr);
	int rc, br = 0;

	for (br = 0; br < CACHE_OFFSET_SZ; br += sizeof(uint32_t)) {
		rc = mem_map_read(cache->mem, addr, 32,
				  &line->data32[br / sizeof(uint32_t)]);
		if (rc)
			break;
	}

	line->valid = !!rc;
	line->dirty = 0;
	line->tag = tag;

	return rc;
}

int cache_read(struct cache *cache, uint32_t addr, unsigned int nr_bits,
	       uint32_t *val)
{
	struct cache_line *line = &cache->lines[addr_index(addr)];
	uint32_t tag = addr_tag(addr);
	uint32_t offs = addr_offs(addr);
	int rc = 0;

	/* Writes not yet implemented. */
	assert(!line->dirty);

	if (!line->valid || tag != line->tag) {
		rc = cache_fill_line(cache, line, addr);
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

out:
	return rc;
}
