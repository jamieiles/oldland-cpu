#ifndef __PERIODIC_H__
#define __PERIODIC_H__

#include <stdbool.h>
#include <stdint.h>

#include "list.h"

struct event_list {
	struct list_head events;
};

static inline void event_list_init(struct event_list *event_list)
{
	list_init(&event_list->events);
}

void event_list_tick(struct event_list *event_list);

struct event {
	struct list_head head;
	uint32_t reload_val;
	uint32_t current;
	void (*callback)(struct event *event);
	void *cookie;
	bool enabled;
};

struct event *event_new(struct event_list *event_list, uint32_t reload_val,
			void (*callback)(struct event *event), void *cookie);
void event_delete(struct event *event);
void event_mod(struct event *event, uint32_t reload_val);

static inline void event_enable(struct event *event)
{
	event->enabled = true;
}

static inline void event_disable(struct event *event)
{
	event->enabled = false;
}

#endif /* __PERIODIC_H__ */
