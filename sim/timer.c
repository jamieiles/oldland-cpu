/*
 * Timers are periodic, starting from the reload value (default 32'hffffffff)
 * and counting down.  If interrupts are enabled then an IRQ is raised when
 * the timer hits zero and the timer reloads if configured in the control
 * register.  The interrupt is cleared by writing the end-of-interrupt
 * register.
 *
 * Register map:
 *   - 0: timer value, read for current value, writes ignored.
 *   - 4: timer reload value, writes reset the timer.
 *   - 8: control register:
 *        - [0]: 1: periodic, 0: one-shot.
 *        - [1]: 1: enabled, self-clears for one-shot after expiry.
 *        - [2]: interrupt enable.
 *   - c: end-of-interrupt register, writes clear interrupts, reads ignored.
 *
 * There are a total of 4 timers, at a 16 byte offset each.
 */
#include <assert.h>
#include <errno.h>
#include <stdio.h>
#include <stdlib.h>

#include "internal.h"
#include "periodic.h"
#include "irq_ctrl.h"
#include "io.h"

enum timer_regs {
	REG_COUNT	= 0x0,
	REG_RELOAD	= 0x4,
	REG_CONTROL	= 0x8,
	REG_EOI		= 0xc,
};

#define CONTROL_PERIODIC	(1 << 0)
#define CONTROL_ENABLED		(1 << 1)
#define CONTROL_IRQ_ENABLE	(1 << 2)

#define NR_TIMERS		4

struct timer {
	struct event *event;
	struct irq_ctrl *irq_ctrl;
	unsigned int irq;
	unsigned timer_num;
	bool periodic;
	bool irq_enabled;
};

struct timer_base {
	struct timer timers[NR_TIMERS];
};

static void timer_callback(struct event *event)
{
	struct timer *t = event->cookie;

	if (!t->periodic)
		event_disable(t->event);

	if (t->irq_enabled)
		irq_ctrl_raise_irq(t->irq_ctrl, t->irq);
}

static int timer_write(unsigned int offs, uint32_t val, size_t nr_bits,
		       void *priv)
{
	struct timer_base *base = priv;
	struct timer *timer;

	if (nr_bits != 32)
		return -EFAULT;

	if (offs >= 16 * NR_TIMERS)
		return 0;

	timer = &base->timers[offs / 16];
	switch (offs % 16) {
	case REG_COUNT:
		break;
	case REG_RELOAD:
		event_mod(timer->event, val);
		break;
	case REG_CONTROL:
		timer->periodic = !!(val & CONTROL_PERIODIC);
		timer->irq_enabled = !!(val & CONTROL_IRQ_ENABLE);
		if (val & CONTROL_ENABLED)
			event_enable(timer->event);
		else
			event_disable(timer->event);
		break;
	case REG_EOI:
		irq_ctrl_clear_irq(timer->irq_ctrl, timer->irq);
		break;
	}

	return 0;
}

static int timer_read(unsigned int offs, uint32_t *val, size_t nr_bits,
		      void *priv)
{
	struct timer_base *base = priv;
	struct timer *timer;

	if (nr_bits != 32)
		return -EFAULT;

	*val = 0;
	if (offs >= 16 * NR_TIMERS)
		return 0;

	timer = &base->timers[offs / 16];
	switch (offs % 16) {
	case REG_COUNT:
		*val = timer->event->current;
		break;
	case REG_RELOAD:
		*val = timer->event->reload_val;
		break;
	case REG_CONTROL:
		*val = (timer->event->enabled ? CONTROL_ENABLED : 0) |
		       (timer->periodic ? CONTROL_PERIODIC : 0) |
		       (timer->irq_enabled ? CONTROL_IRQ_ENABLE : 0);
		break;
	case REG_EOI:
		*val = 0;
		break;
	}

	return 0;
}

static const struct io_ops timer_ops = {
	.write = timer_write,
	.read = timer_read,
};

struct timer_base *timers_init(struct mem_map *mem, physaddr_t base,
			       struct event_list *events,
			       const struct timer_init_data *init_data)
{
	struct region *r;
	struct timer_base *t = calloc(1, sizeof(*t));
	int i;

	assert(t != NULL);

	for (i = 0; i < NR_TIMERS; ++i) {
		t->timers[i].timer_num = i;
		t->timers[i].event = event_new(events, 0xffffffff,
					       timer_callback, &t->timers[i]);
		t->timers[i].irq_ctrl = init_data->irq_ctrl;
		t->timers[i].irq = init_data->irqs[i];
		assert(t->timers[i].event != NULL);
	}

	r = mem_map_region_add(mem, base, 4096, &timer_ops, t);
	assert(r != NULL);

	return t;
}

void timers_reset(struct timer_base *t)
{
	int i;

	for (i = 0; i < NR_TIMERS; ++i) {
		event_disable(t->timers[i].event);
		t->timers[i].event->current = 0xffffffff;
		t->timers[i].event->reload_val = 0xffffffff;
	}
}
