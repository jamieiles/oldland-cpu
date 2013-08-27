.equ	TP_SUCCESS,	0x1
.equ	TP_FAILURE,	0x2
.equ	TP_USER,	0x4

.macro	TESTPOINT	type, tag
.if	\type & (TP_SUCCESS | TP_FAILURE)
1:	b	1b
.else
1:	nop
.endif
.pushsection	".testpoints"
	.long	1b
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
