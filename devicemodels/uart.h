#ifndef __UART_H__
#define __UART_H__

#ifdef __cplusplus
extern "C" {
#endif

struct uart_data {
	int fd;
};

int create_pts(void);
int sim_is_interactive(void);

#ifdef __cplusplus
};
#endif

#endif /* __UART_H__ */
