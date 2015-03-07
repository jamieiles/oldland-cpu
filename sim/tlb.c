#include <assert.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "tlb.h"

#define PAGE_OFFSET		(4096 - 1)
#define PAGE_MASK		~(4096 - 1)

struct tlb_entry {
	uint32_t virt;
	uint32_t phys;
	int valid;
};

struct tlb {
	uint32_t next_virt;
	int victim_sel;
	unsigned int num_entries;
	struct tlb_entry entries[];
};

struct tlb *tlb_new(unsigned int num_entries)
{
	struct tlb *t;
	size_t alloc_size = sizeof(*t) + (num_entries * sizeof(struct tlb_entry));

	t = malloc(alloc_size);
	assert(t != NULL);
	memset(t, 0, alloc_size);
	t->num_entries = num_entries;

	return t;
}

void tlb_inval(struct tlb *tlb)
{
	unsigned m;

	for (m = 0; m < tlb->num_entries; ++m)
		tlb->entries[m].valid = 0;
}

static struct tlb_entry *tlb_find_mapping(struct tlb *tlb, uint32_t virt)
{
	unsigned m;

	for (m = 0; m < tlb->num_entries; ++m) {
		struct tlb_entry *entry = &tlb->entries[m];

		if (!entry->valid)
			continue;

		if ((entry->virt & PAGE_MASK) == (virt & PAGE_MASK))
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
	entry->phys = phys & PAGE_MASK;
	entry->valid = 1;

	tlb->victim_sel = (tlb->victim_sel + 1) % tlb->num_entries;
}

void tlb_set_virt(struct tlb *tlb, uint32_t virt)
{
	tlb->next_virt = virt;
}

int tlb_translate(struct tlb *tlb, struct translation *translation)
{
	struct tlb_entry *entry = tlb_find_mapping(tlb, translation->virt);
	uint32_t perms;

	if (!entry)
		return -1;

	/*
	 * Permissions are [3:2] for user, [1:0] for supervisor.
	 */
	perms = entry->virt & 0xf;
	if (translation->in_user_mode)
		perms >>= 2;
	perms &= TLB_PERMS_MASK;

	translation->phys = entry->phys | (translation->virt & PAGE_OFFSET);
	translation->perms = perms;

	return 0;
}
