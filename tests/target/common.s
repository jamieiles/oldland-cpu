.equ	TP_SUCCESS,	0x1
.equ	TP_FAILURE,	0x2
.equ	TP_USER,	0x4

.macro	TESTPOINT	type, tag
.if	\type & (TP_SUCCESS | TP_FAILURE)
10001:	b	10001b
.else
10001:	nop
.endif
.pushsection	".testpoints"
	.long	10001b
	.word	\type
	.word	\tag
.popsection
.endm

.macro	SUCCESS
	TESTPOINT	TP_SUCCESS, 0
.endm

.macro	FAILURE
	TESTPOINT	TP_FAILURE, 0
.endm

.macro	push	reg
	str32	\reg, [$sp, 0]
	sub	$sp, $sp, 4
.endm

.macro	pop	reg
	add	$sp, $sp, 4
	ldr32	\reg, [$sp, 0]
.endm
