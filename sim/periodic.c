#include <assert.h>
#include <stdio.h>
#include <stdlib.h>

#include "internal.h"
#include "periodic.h"

struct event *event_new(struct event_list *event_list, uint32_t reload_val,
			void (*callback)(struct event *event), void *cookie)
{
	struct event *event = calloc(1, sizeof(*event));

	assert(event != NULL);

	event->reload_val = reload_val;
	event->current = reload_val;
	event->callback = callback;
	event->cookie = cookie;
	list_add_tail(&event->head, &event_list->events);

	return event;
}

void event_list_tick(struct event_list *event_list)
{
	struct list_head *pos;

	list_for_each(pos, &event_list->events) {
		struct event *event = container_of(pos, struct event, head);

		if (--event->current == 0) {
			event->current = event->reload_val;
			event->callback(event);
		}
	}
}

void event_delete(struct event *event)
{
	list_del(&event->head);
	free(event);
}

void event_mod(struct event *event, uint32_t reload_val)
{
	event->reload_val = reload_val;
	event->current = reload_val;
}
