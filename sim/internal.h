#ifndef __INTERNAL_H__
#define __INTERNAL_H__

#include <stdarg.h>
#include <stdbool.h>
#include <stdlib.h>
#include <stdio.h>

static inline ssize_t no_printf(const char *fmt, ...) { return 0; }

#ifdef DEBUG
#define debug printf
#else /* !DEBUG */
#define debug no_printf
#endif /* DEBUG */

#define ARRAY_SIZE(_a) (sizeof((_a)) / sizeof((_a)[0]))

#ifndef offsetof
#define offsetof(type, member) __builtin_offsetof(type, member)
#endif /* offsetof */
#define container_of(ptr, type, member) ({ \
	(type *)(((char *)(ptr)) - offsetof(type, member)); \
})

static inline void __die(const char *file, unsigned int line, const char *fmt, ...)
{
	va_list ap;

	va_start(ap, fmt);
	fprintf(stderr, "[sim] died at %s:%u: ", file, line);
	vfprintf(stderr, fmt, ap);
	va_end(ap);

	exit(EXIT_FAILURE);
}
#define die(fmt, ...) __die(__FILE__, __LINE__, (fmt), ##__VA_ARGS__)

extern bool interactive_mode;

#endif /* __INTERNAL_H__ */
