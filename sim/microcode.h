#ifndef __MICROCODE_H__
#define __MICROCODE_H__

#include <stdint.h>

#include "oldland-types.h"

enum imsel {
	IMSEL_IMM13,
	IMSEL_IMM24,
	IMSEL_HI16,
	IMSEL_LO16
};

enum maw {
	MAW_8,
	MAW_16,
	MAW_32
};

static inline unsigned ucode_cache(uint32_t ucode)
{
	return ucode >> 26 & 0x1;
}

static inline unsigned ucode_upc(uint32_t ucode)
{
	return ucode >> 25 & 0x1;
}

static inline unsigned ucode_rfe(uint32_t ucode)
{
	return ucode >> 24 & 0x1;
}

static inline unsigned ucode_swi(uint32_t ucode)
{
	return ucode >> 23 & 0x1;
}

static inline unsigned ucode_wcr(uint32_t ucode)
{
	return ucode >> 22 & 0x1;
}

static inline unsigned ucode_valid(uint32_t ucode)
{
	return ucode >> 21 & 0x1;
}

static inline enum imsel ucode_imsel(uint32_t ucode)
{
	return ucode >> 19 & 0x3;
}

static inline unsigned ucode_bcc(uint32_t ucode)
{
	return ucode >> 16 & 0x7;
}

static inline enum maw ucode_maw(uint32_t ucode)
{
	return ucode >> 14 & 0x3;
}

static inline unsigned ucode_icall(uint32_t ucode)
{
	return ucode >> 13 & 0x1;
}

static inline unsigned ucode_rdlr(uint32_t ucode)
{
	return ucode >> 12 & 0x1;
}

static inline unsigned ucode_mstr(uint32_t ucode)
{
	return ucode >> 11 & 0x1;
}

static inline unsigned ucode_mldr(uint32_t ucode)
{
	return ucode >> 10 & 0x1;
}

static inline unsigned ucode_op2rb(uint32_t ucode)
{
	return ucode >> 9 & 0x1;
}

static inline unsigned ucode_op1rb(uint32_t ucode)
{
	return ucode >> 8 & 0x1;
}

static inline unsigned ucode_op1ra(uint32_t ucode)
{
	return ucode >> 7 & 0x1;
}

static inline unsigned ucode_upcc(uint32_t ucode)
{
	return ucode >> 6 & 0x1;
}

static inline unsigned ucode_wrrd(uint32_t ucode)
{
	return ucode >> 5 & 0x1;
}

static inline enum alu_opcode ucode_aluop(uint32_t ucode)
{
	return ucode & 0x1f;
}

#endif /* __MICROCODE_H__ */
