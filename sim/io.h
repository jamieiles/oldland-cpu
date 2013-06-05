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
#ifndef __IO_H__
#define __IO_H__

#include <stdint.h>

#define PAGE_SIZE		(1 << 12)

typedef uint32_t physaddr_t;
struct region;

struct mem_map;

struct mem_map *mem_map_new(void);

struct io_ops {
	int (*write)(unsigned int offs, uint32_t val, size_t nr_bits,
		     void *priv);
	int (*read)(unsigned int offs, uint32_t *val, size_t nr_bits,
		    void *priv);
};

/*
 * Add a new I/O region.  Returned as a cookie for further use.
 */
struct region *mem_map_region_add(struct mem_map *map, physaddr_t base,
				  size_t len, const struct io_ops *ops,
				  void *priv);
int mem_map_write(struct mem_map *map, physaddr_t addr, unsigned int nr_bits,
		  uint32_t val);
int mem_map_read(struct mem_map *map, physaddr_t addr, unsigned int nr_bits,
		 uint32_t *val);

/*
 * Devices.
 */
int debug_uart_init(struct mem_map *mem, physaddr_t base, size_t len);
int ram_init(struct mem_map *mem, physaddr_t base, size_t len,
	     const char *init_contents);
int rom_init(struct mem_map *mem, physaddr_t base, size_t len,
	     const char *filename);
int sdram_ctrl_init(struct mem_map *mem, physaddr_t base, size_t len);

#endif /* __IO_H__ */
