#include <assert.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "tlb.h"

#define NUM_TLB_ENTRIES		8
#define PAGE_OFFSET		(4096 - 1)
#define PAGE_MASK		~(4096 - 1)

struct tlb_entry {
	uint32_t virt;
	uint32_t phys;
	int valid;
};

struct tlb {
	struct tlb_entry entries[NUM_TLB_ENTRIES];
	uint32_t next_virt;
	int victim_sel;
};

struct tlb *tlb_new(void)
{
	struct tlb *t = malloc(sizeof(*t));

	assert(t != NULL);
	memset(t, 0, sizeof(*t));

	return t;
}

void tlb_inval(struct tlb *tlb)
{
	unsigned m;

	for (m = 0; m < NUM_TLB_ENTRIES; ++m)
		tlb->entries[m].valid = 0;
}

static struct tlb_entry *tlb_find_mapping(struct tlb *tlb, uint32_t virt)
{
	unsigned m;

	for (m = 0; m < NUM_TLB_ENTRIES; ++m) {
		struct tlb_entry *entry = &tlb->entries[m];

		if (!entry->valid)
			continue;

		if (entry->virt == (virt & PAGE_MASK))
			return entry;
	}

	return NULL;
}

void tlb_set_phys(struct tlb *tlb, uint32_t phys)
{
	struct tlb_entry *entry;
	
	entry = tlb_find_mapping(tlb, tlb->next_virt);
	if (!entry)
		entry = &tlb->entries[tlb->victim_sel];

	entry->virt = tlb->next_virt;
	entry->phys = phys;
	entry->valid = 1;

	tlb->victim_sel = (tlb->victim_sel + 1) % NUM_TLB_ENTRIES;
}

void tlb_set_virt(struct tlb *tlb, uint32_t virt)
{
	tlb->next_virt = virt;
}

int tlb_translate(struct tlb *tlb, struct translation *translation)
{
	struct tlb_entry *entry = tlb_find_mapping(tlb, translation->virt);

	if (!entry)
		return -1;

	translation->phys = entry->phys | (translation->virt & PAGE_OFFSET);

	return 0;
}
