/*
 * User breakpoints.
 *
 * Breakpoints are implemented by replacing the instruction at the target
 * address with a 'bkp' instruction.
 *
 * Users register a breakpoint with breakpoint_register().  When execution
 * stops, use breakpoint_at_addr() to determine whether an enabled breakpoint
 * was hit or not.  If it was then execution must be resumed with
 * breakpoint_exec_orig().  This replaces the instruction at the breakpoint
 * address with the real instruction, steps for a single cycle to run the real
 * instruction then puts the breakpoint back.
 */
#include <assert.h>
#include <err.h>
#include <errno.h>
#include <limits.h>
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>

#include "breakpoint.h"
#include "debugger.h"
#include "list.h"
#include "oldland-types.h"

static const uint32_t bkp_insn = (3 << 30 | OPCODE_BKP << 26);
static int next_id;
DEFINE_LIST(bkp_list);

struct breakpoint *breakpoint_register(struct target *t, uint32_t addr)
{
	struct breakpoint *bkp = malloc(sizeof(*bkp));

	assert(bkp != NULL);
	memset(bkp, 0, sizeof(*bkp));

	bkp->addr = addr;
	bkp->target = t;
	bkp->id = next_id++;
	/* Until we have a need for lots of breakpoints this'll do. */
	assert(next_id != INT_MAX);

	if (breakpoint_enable(bkp)) {
		free(bkp);
		return NULL;
	}

	list_add_tail(&bkp->head, &bkp_list);

	return bkp;
}

int breakpoint_enable(struct breakpoint *bkp)
{
	if (bkp->enabled)
		return 0;

	if (dbg_read32(bkp->target, bkp->addr, &bkp->orig_instr) ||
	    dbg_write32(bkp->target, bkp->addr, bkp_insn)) {
		warnx("failed to write breakpoint at %08x", bkp->addr);
		return -EIO;
	}

	bkp->enabled = true;

	return 0;
}

int breakpoint_disable(struct breakpoint *bkp)
{
	if (!bkp->enabled)
		return 0;

	if (dbg_write32(bkp->target, bkp->addr, bkp->orig_instr)) {
		warnx("failed to write breakpoint at %08x", bkp->addr);
		return -EIO;
	}

	bkp->enabled = false;

	return 0;
}

int breakpoint_remove(struct breakpoint *bkp)
{
	if (breakpoint_disable(bkp)) {
		warnx("failed to remove breakpoint");
		return -EIO;
	}

	list_del(&bkp->head);
	free(bkp);

	return 0;
}

struct breakpoint *breakpoint_get(int id)
{
	struct list_head *pos;

	list_for_each(pos, &bkp_list) {
		struct breakpoint *bp = to_breakpoint(pos);

		if (bp->id == id)
			return bp;
	}

	return NULL;
}

struct breakpoint *breakpoint_at_addr(uint32_t addr)
{
	struct list_head *pos;

	list_for_each(pos, &bkp_list) {
		struct breakpoint *bp = to_breakpoint(pos);

		if (bp->addr == addr)
			return bp;
	}

	return NULL;
}

void breakpoint_exec_orig(struct breakpoint *bkp)
{
	if (breakpoint_disable(bkp) || dbg_step(bkp->target) ||
	    breakpoint_enable(bkp))
		err(1, "failed to execute instruction at breakpoint (%08x)",
		    bkp->addr);
}
