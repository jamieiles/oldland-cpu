#ifndef __JTAG_H__
#define __JTAG_H__

#include "../debugger/protocol.h"

struct jtag_debug_data {
	int sock_fd;
	int epoll_fd;
	int client_fd;
	int pending;
	int more_data;
	pthread_mutex_t lock;
};

struct jtag_debug_data *start_server(void);
int send_response(struct jtag_debug_data *d, const struct dbg_response *resp);
int get_request(struct jtag_debug_data *d, struct dbg_request *req);
void notify_runner(void);

#endif /* __JTAG_H__ */
