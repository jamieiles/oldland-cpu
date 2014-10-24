.include "common.s"

.globl _start
_start:
	mov	$r12, 0x60 /* I+D cache enable. */
	scr	1, $r12
	/* Wait for SDRAM to initialize. */
	movhi	$r0, 0x8000
	orlo	$r0, $r0, 0x1000
1:
	ldr32	$r1, [$r0, 0]
	cmp	$r1, 0x0
	beq	1b

	movhi	$r0, %hi(hello_world)
	orlo	$r0, $r0, %lo(hello_world)

	movhi	$r1, %hi(end)
	orlo	$r1, $r1, %lo(end)

	movhi	$r3, 0x2000

2:
	cmp	$r0, $r1
	beq	success

	ldr8	$r2, [$r0, 0]
	str8	$r2, [$r3, 0]
	add	$r0, $r0, 1
	add	$r3, $r3, 1

	b	2b

success:
	TESTPOINT	TP_USER, 0
	SUCCESS

hello_world:
	.asciz "Hello, world!"
end:
