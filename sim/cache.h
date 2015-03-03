#ifndef __CACHE_H__
#define __CACHE_H__

#include <stdint.h>

struct mem_map;

struct cache *cache_new(struct mem_map *mem);

void cache_inval_index(struct cache *cache, uint32_t indx);
void cache_inval_all(struct cache *cache);
int cache_flush_index(struct cache *cache, uint32_t indx);
int cache_flush_all(struct cache *cache);
int cache_read(struct cache *cache, uint32_t virt, uint32_t phys,
	       unsigned int nr_bits, uint32_t *val);
int cache_write(struct cache *cache, uint32_t virt, uint32_t phys,
		unsigned int nr_bits, uint32_t val);

#endif /* __CACHE_H__ */
