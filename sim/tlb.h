#ifndef __TLB_H__
#define __TLB_H__

struct tlb;

enum tlb_perms {
	TLB_READ = (1 << 0),
	TLB_WRITE = (1 << 1),
	TLB_PERMS_MASK = (1 << 2) - 1,
};

struct translation {
	uint32_t virt;
	uint32_t phys;
	uint32_t perms;
};

struct tlb *tlb_new(void);
void tlb_inval(struct tlb *tlb);
void tlb_set_phys(struct tlb *tlb, uint32_t phys);
void tlb_set_virt(struct tlb *tlb, uint32_t virt);
int tlb_translate(struct tlb *tlb, struct translation *translation);

#endif /* __TLB_H__ */
