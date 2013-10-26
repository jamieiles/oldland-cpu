#ifndef __IRQ_CTRL_H__
#define __IRQ_CTRL_H__

#include "io.h"

struct irq_ctrl;

struct irq_ctrl *irq_ctrl_init(struct mem_map *mem, physaddr_t base,
			       void (*cpu_raise_irq)(void *data),
			       void (*cpu_clear_irq)(void *data), void *data);
void irq_ctrl_raise_irq(struct irq_ctrl *ctrl, unsigned int irq_num);
void irq_ctrl_clear_irq(struct irq_ctrl *ctrl, unsigned int irq_num);
void irq_ctrl_reset(struct irq_ctrl *irq_ctrl);

#endif /* __IRQ_CTRL_H__ */
