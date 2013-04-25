#ifndef __LIST_H__
#define __LIST_H__

struct list_head {
	struct list_head *prev;
	struct list_head *next;
};

#define DEFINE_LIST(name) \
	struct list_head name = { .prev = &name, .next = &name }

static inline void list_init(struct list_head *l)
{
	l->prev = l->next = l;
}

static inline void list_add(struct list_head *new, struct list_head *list)
{
	new->prev = list;
	new->next = list->next;
	list->next->prev = new;
	list->next = new;
}

static inline void list_add_tail(struct list_head *new, struct list_head *list)
{
	new->prev = list->prev;
	new->next = list;
	list->prev->next = new;
	list->prev = new;
}

static inline void list_del(struct list_head *h)
{
	struct list_head *next = h->next, *prev = h->prev;

	prev->next = next;
	next->prev = prev;
}

#define list_for_each(pos, list) \
	for ((pos) = (list)->next; (pos) != (list); (pos) = (pos)->next)

#endif /* __LIST_H__ */
