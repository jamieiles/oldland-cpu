.macro	push	reg
	str32	\reg, [$sp, 0]
	sub	$sp, $sp, 4
.endm

.macro	pop	reg
	add	$sp, $sp, 4
	ldr32	\reg, [$sp, 0]
.endm

.macro  push2   a, b
        sub     $sp, $sp, 12
        str32   \a, [$sp, 4]
        str32   \b, [$sp, 8]
.endm

.macro  pop2    a, b
        ldr32   \b, [$sp, 8]
        ldr32   \a, [$sp, 4]
        add    $sp, $sp, 12
.endm

.macro  push3   a, b, c
        sub     $sp, $sp, 16
        str32   \a, [$sp, 4]
        str32   \b, [$sp, 8]
        str32   \c, [$sp, 12]
.endm

.macro  pop3    a, b, c
        ldr32   \c, [$sp, 12]
        ldr32   \b, [$sp, 8]
        ldr32   \a, [$sp, 4]
        add    $sp, $sp, 16
.endm

.macro  push4   a, b, c, d
        sub     $sp, $sp, 20
        str32   \a, [$sp, 4]
        str32   \b, [$sp, 8]
        str32   \c, [$sp, 12]
        str32   \d, [$sp, 16]
.endm

.macro  pop4    a, b, c, d
        ldr32   \d, [$sp, 16]
        ldr32   \c, [$sp, 12]
        ldr32   \b, [$sp, 8]
        ldr32   \a, [$sp, 4]
        add    $sp, $sp, 20
.endm

.macro  push5   a, b, c, d, e
        sub     $sp, $sp, 24
        str32   \a, [$sp, 4]
        str32   \b, [$sp, 8]
        str32   \c, [$sp, 12]
        str32   \d, [$sp, 16]
        str32   \e, [$sp, 20]
.endm

.macro  pop5    a, b, c, d, e
        ldr32   \e, [$sp, 20]
        ldr32   \d, [$sp, 16]
        ldr32   \c, [$sp, 12]
        ldr32   \b, [$sp, 8]
        ldr32   \a, [$sp, 4]
        add    $sp, $sp, 24
.endm

.macro  push6   a, b, c, d, e, f
        sub     $sp, $sp, 28
        str32   \a, [$sp, 4]
        str32   \b, [$sp, 8]
        str32   \c, [$sp, 12]
        str32   \d, [$sp, 16]
        str32   \e, [$sp, 20]
        str32   \f, [$sp, 24]
.endm

.macro  pop6    a, b, c, d, e, f
        ldr32   \f, [$sp, 24]
        ldr32   \e, [$sp, 20]
        ldr32   \d, [$sp, 16]
        ldr32   \c, [$sp, 12]
        ldr32   \b, [$sp, 8]
        ldr32   \a, [$sp, 4]
        add    $sp, $sp, 28
.endm
