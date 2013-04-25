#ifndef __INTERNAL_H__
#define __INTERNAL_H__

#include <stdlib.h>

static inline ssize_t no_printf(const char *fmt, ...) { return 0; }

#ifdef DEBUG
#define debug printf
#else /* !DEBUG */
#define debug no_printf
#endif /* DEBUG */

#define ARRAY_SIZE(_a) (sizeof((_a)) / sizeof((_a)[0]))

#define offsetof(type, member) __builtin_offsetof(type, member)
#define container_of(ptr, type, member) ({ \
	(type *)(((char *)(ptr)) - offsetof(type, member)); \
})

#endif /* __INTERNAL_H__ */
