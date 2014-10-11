#include "common.h"
#include "string.h"
#include "uart.h"

void boot_from_sd(void);

void data_abort_handler(unsigned long faultpc, unsigned long faultaddr)
{
	putstr("data abort");

	for (;;)
		continue;
}

void root(void)
{
	boot_from_sd();
}
