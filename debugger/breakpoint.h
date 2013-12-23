#ifndef __BREAKPOINT_H__
#define __BREAKPOINT_H__

#include <stdbool.h>

#include "list.h"

#ifndef offsetof
#define offsetof(type, member) __builtin_offsetof(type, member)
#endif /* offsetof */
#define container_of(ptr, type, member) ({ \
	(type *)(((char *)(ptr)) - offsetof(type, member)); \
})

struct target;

struct breakpoint {
	int id;
	bool enabled;
	uint32_t addr;
	struct list_head head;
	uint32_t orig_instr;
	struct target *target;
};

static inline struct breakpoint *to_breakpoint(struct list_head *h)
{
	return container_of(h, struct breakpoint, head);
}

struct breakpoint *breakpoint_register(struct target *, uint32_t addr);
int breakpoint_remove(struct breakpoint *bkp);
int breakpoint_enable(struct breakpoint *bkp);
int breakpoint_disable(struct breakpoint *bkp);
struct breakpoint *breakpoint_get(int id);
struct breakpoint *breakpoint_at_addr(uint32_t addr);
void breakpoint_exec_orig(struct breakpoint *bkp);

extern struct list_head bkp_list;

#endif /* __BREAKPOINT_H__ */
