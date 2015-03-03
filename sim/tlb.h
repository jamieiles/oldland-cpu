#ifndef __TLB_H__
#define __TLB_H__

struct tlb;

struct translation {
	uint32_t virt;
	uint32_t phys;
};

struct tlb *tlb_new(void);
void tlb_inval(struct tlb *tlb);
void tlb_set_phys(struct tlb *tlb, uint32_t phys);
void tlb_set_virt(struct tlb *tlb, uint32_t virt);
int tlb_translate(struct tlb *tlb, struct translation *translation);

#endif /* __TLB_H__ */
