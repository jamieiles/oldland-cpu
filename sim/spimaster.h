#ifndef __SPIMASTER_H__
#define __SPIMASTER_H__

#include <stdbool.h>
#include <stdint.h>

#include "io.h"

struct spislave {
	unsigned int csnum;
	void (*exchange_bytes)(struct spislave *slave, uint8_t rxbyte,
			       uint8_t *txbyte);
};

struct spimaster;

struct spimaster *spimaster_init(struct mem_map *mem, physaddr_t base,
				 struct spislave **slaves, size_t nr_slaves);

#endif /* __SPIMASTER_H__ */
