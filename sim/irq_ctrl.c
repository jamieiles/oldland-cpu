#include <assert.h>
#include <errno.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>

#include "internal.h"
#include "io.h"

enum irq_ctrl_regs {
	IRQ_CTRL_STATUS		= 0x0,
	IRQ_CTRL_ENABLE		= 0x4,
	IRQ_CTRL_DISABLE	= 0x8,
	IRQ_CTRL_TEST		= 0xc,
};

struct irq_ctrl {
	uint32_t	status;
	uint32_t	raw_status;
	uint32_t	enable_mask;
	void		(*cpu_raise_irq)(void *data);
	void		(*cpu_clear_irq)(void *data);
	void		*cb_data;
	bool		irq_raised;
};

static void irq_ctrl_update(struct irq_ctrl *ctrl)
{
	ctrl->status = ctrl->raw_status & ctrl->enable_mask;

	if (ctrl->status && !ctrl->irq_raised) {
		ctrl->cpu_raise_irq(ctrl->cb_data);
		ctrl->irq_raised = true;
	} else if (ctrl->irq_raised) {
		ctrl->cpu_clear_irq(ctrl->cb_data);
		ctrl->irq_raised = false;
	}
}

static int irq_ctrl_write(unsigned int offs, uint32_t val, size_t nr_bits,
			  void *priv)
{
	struct irq_ctrl *ctrl = priv;

	if (nr_bits != 32)
		return -EFAULT;

	switch (offs) {
	case IRQ_CTRL_ENABLE:
		ctrl->enable_mask |= val;
		irq_ctrl_update(ctrl);
		break;
	case IRQ_CTRL_DISABLE:
		ctrl->enable_mask &= ~val;
		irq_ctrl_update(ctrl);
		break;
	case IRQ_CTRL_TEST:
		ctrl->raw_status = val;
		irq_ctrl_update(ctrl);
		break;
	case IRQ_CTRL_STATUS:
		/* Fallthrough. */
	default:
		break;
	}

	return 0;
}

static int irq_ctrl_read(unsigned int offs, uint32_t *val, size_t nr_bits,
			 void *priv)
{
	struct irq_ctrl *ctrl = priv;

	if (nr_bits != 32)
		return -EFAULT;

	switch (offs) {
	case IRQ_CTRL_ENABLE:
		*val = ctrl->enable_mask;
		break;
	case IRQ_CTRL_DISABLE:
		*val = ~ctrl->enable_mask;
		break;
	case IRQ_CTRL_STATUS:
		*val = ctrl->status;
		break;
	case IRQ_CTRL_TEST:
		/* Fallthrough. */
	default:
		*val = 0;
		break;
	}

	return 0;
}

void irq_ctrl_raise_irq(struct irq_ctrl *ctrl, unsigned int irq_num)
{
	assert(irq_num < 32);

	ctrl->raw_status |= (1 << irq_num);
	irq_ctrl_update(ctrl);
}

void irq_ctrl_clear_irq(struct irq_ctrl *ctrl, unsigned int irq_num)
{
	assert(irq_num < 32);

	ctrl->raw_status &= ~(1 << irq_num);
	irq_ctrl_update(ctrl);
}

static const struct io_ops irq_ctrl_ops = {
	.write = irq_ctrl_write,
	.read = irq_ctrl_read,
};

struct irq_ctrl *irq_ctrl_init(struct mem_map *mem, physaddr_t base,
			       void (*cpu_raise_irq)(void *data),
			       void (*cpu_clear_irq)(void *data), void *data)
{
	struct region *r;
	struct irq_ctrl *ctrl;

	ctrl = calloc(1, sizeof(*ctrl));
	assert(ctrl);

	ctrl->cpu_raise_irq = cpu_raise_irq;
	ctrl->cpu_clear_irq = cpu_clear_irq;
	ctrl->cb_data = data;

	r = mem_map_region_add(mem, base, 4096, &irq_ctrl_ops, ctrl);
	assert(r);

	return ctrl;
}
