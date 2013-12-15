.equ	TP_SUCCESS,	0x1
.equ	TP_FAILURE,	0x2
.equ	TP_USER,	0x4

.macro	TESTPOINT	type, tag
10001:	bkp
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
