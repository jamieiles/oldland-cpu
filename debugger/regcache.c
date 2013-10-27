#define _GNU_SOURCE
#include <errno.h>
#include <stdio.h>
#include <stdlib.h>

#include "debugger.h"

struct regcache {
	struct target *target;
	uint64_t valid_mask;
	uint64_t dirty_mask;
	uint32_t regs[NR_REGS];
};

struct regcache *regcache_new(struct target *target)
{
	struct regcache *r = calloc(1, sizeof(*r));

	if (r)
		r->target = target;

	return r;
}

void regcache_free(struct regcache *r)
{
	free(r);
}

int regcache_sync(struct regcache *r)
{
	int rc = 0;
	unsigned reg = 0;

	for (reg = 0; reg < NR_REGS; ++reg) {
		if (r->dirty_mask & (1 << reg)) {
			rc = dbg_write_reg(r->target, reg, r->regs[reg]);
			if (rc)
				break;
		}
	}

	r->dirty_mask = r->valid_mask = 0;

	return rc;
}

int regcache_read(struct regcache *r, enum regs reg, uint32_t *val)
{
	int rc = 0;

	if (reg >= NR_REGS || reg < 0)
		return -EINVAL;

	if (r->valid_mask & (1 << reg)) {
		*val = r->regs[reg];
		return 0;
	}

	rc = dbg_read_reg(r->target, reg, &r->regs[reg]);
	if (!rc) {
		if (val)
			*val = r->regs[reg];
		r->valid_mask |= (1 << reg);
	}

	return rc;
}

int regcache_write(struct regcache *r, enum regs reg, uint32_t val)
{
	int rc = 0;

	if (reg >= NR_REGS || reg < 0)
		return -EINVAL;

	r->regs[reg] = val;
	r->valid_mask |= (1 << reg);
	r->dirty_mask |= (1 << reg);

	return rc;
}
