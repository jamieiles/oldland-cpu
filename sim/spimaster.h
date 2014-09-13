#ifndef __SPIMASTER_H__
#define __SPIMASTER_H__

#include <stdbool.h>
#include <stdint.h>

#include "io.h"

struct spislave {
	void (*exchange_bytes)(struct spislave *slave, uint8_t master_to_slave,
			       uint8_t *slave_to_master);
	void *privdata;
};

struct spimaster;

struct spimaster *spimaster_init(struct mem_map *mem, physaddr_t base,
				 struct spislave **slaves, size_t nr_slaves);

#endif /* __SPIMASTER_H__ */
