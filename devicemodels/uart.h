#ifndef __UART_H__
#define __UART_H__

struct uart_data {
	int fd;
};

int create_pts(void);
int sim_is_interactive(void);

#endif /* __UART_H__ */
