#ifndef __UART_H__
#define __UART_H__

#ifdef __cplusplus
extern "C" {
#endif

struct uart_data {
	int fd;
#ifdef EMSCRIPTEN
	char next_rx;
	int next_rx_valid;
#endif
};

int create_pts(void);
int sim_is_interactive(void);

#ifdef __cplusplus
};
#endif

#endif /* __UART_H__ */
