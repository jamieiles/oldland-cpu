#include "uart.h"

#define UART_BASE		0x80000000
#define UART_DATA_OFFS		0x0
#define UART_STATUS_OFFS	0x4
#define UART_STATUS_TX_EMPTY	(1 << 0)
#define UART_STATUS_RX_READY	(1 << 1)

static unsigned long uart_read(unsigned offs)
{
	volatile unsigned long *reg = (volatile unsigned long *)(UART_BASE + offs);

	return *reg;
}

static void uart_write(unsigned offs, unsigned long val)
{
	volatile unsigned long *reg = (volatile unsigned long *)(UART_BASE + offs);

	*reg = val;
}

static void uart_wait_tx_empty(void)
{
	unsigned long status;

	do {
		status = uart_read(UART_STATUS_OFFS);
	} while (!(status & UART_STATUS_TX_EMPTY));
}

void uart_putc(int c)
{
	uart_wait_tx_empty();
	uart_write(UART_DATA_OFFS, c);
}

int uart_getc(void)
{
	unsigned long status;

	do {
		status = uart_read(UART_STATUS_OFFS);
	} while (!(status & UART_STATUS_RX_READY));

	return uart_read(UART_DATA_OFFS);
}
