#include <stdarg.h>
#include <stdlib.h>
#include <stdio.h>

static inline void __attribute__((noreturn)) __die(const char *file, unsigned int line, const char *fmt, ...)
{
	va_list ap;

	va_start(ap, fmt);
	fprintf(stderr, "[sim] died at %s:%u: ", file, line);
	vfprintf(stderr, fmt, ap);
	va_end(ap);

	exit(EXIT_FAILURE);
}
#define die(fmt, ...) __die(__FILE__, __LINE__, (fmt), ##__VA_ARGS__)

static inline void warn(const char *fmt, ...)
{
	va_list ap;

	va_start(ap, fmt);
	vfprintf(stderr, fmt, ap);
	va_end(ap);
}
