#define _GNU_SOURCE
#include <assert.h>
#include <err.h>
#include <errno.h>
#include <fcntl.h>
#include <libgen.h>
#include <netdb.h>
#include <pthread.h>
#include <stdarg.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#include <sys/epoll.h>
#include <sys/uio.h>
#include <sys/socket.h>
#include <sys/types.h>

#include "cpu.h"
#include "internal.h"

#include "../debugger/protocol.h"

struct debug_data {
	int sock_fd;
	int epoll_fd;
	int client_fd;
	int pending;
	int more_data;
	pthread_mutex_t lock;

	uint32_t debug_regs[4];
};

static int get_request(struct debug_data *d, struct dbg_request *req)
{
	ssize_t br;
	int rc = -EAGAIN;

	pthread_mutex_lock(&d->lock);

	if (d->client_fd < 0)
		goto out;

	if (!d->more_data)
		goto out;

	br = read(d->client_fd, req, sizeof(*req));
	if (br < 0 && errno == EAGAIN) {
		d->more_data = 0;
	} else if (br != sizeof(*req)) {
		d->more_data = 0;
		rc = -EIO;
	} else {
		rc = 0;
	}

out:
	pthread_mutex_unlock(&d->lock);

	return rc;
}

static int send_response(struct debug_data *d, const struct dbg_response *resp)
{
	ssize_t bs;
	struct iovec iov = {
		.iov_base = (void *)resp,
		.iov_len = sizeof(*resp)
	};

	bs = writev(d->client_fd, &iov, 1);
	if (bs < 0 && errno == EAGAIN)
		return -EAGAIN;
	else if (bs != sizeof(*resp))
		return -EIO;

	return 0;
}

static void enable_reuseaddr(int fd)
{
	int val = 1;

	if (setsockopt(fd, SOL_SOCKET, SO_REUSEADDR, &val, sizeof(val)))
		err(1, "failed to enable SO_REUSEADDR");
}

static int spawn_server(void)
{
	struct addrinfo *result, *rp, hints = {
		.ai_family	= AF_INET,
		.ai_socktype	= SOCK_STREAM,
		.ai_flags	= AI_PASSIVE,
	};
	int s, fd;

	s = getaddrinfo(NULL, "36000", &hints, &result);
	if (s)
		err(1, "getaddrinfo failed");

	for (rp = result; rp; rp = rp->ai_next) {
		fd = socket(rp->ai_family, rp->ai_socktype, rp->ai_protocol);
		if (fd < 0)
			continue;

		enable_reuseaddr(fd);

		if (!bind(fd, rp->ai_addr, rp->ai_addrlen))
			break;

		close(fd);
	}

	if (!rp)
		err(1, "failed to bind server");

	freeaddrinfo(result);

	if (listen(fd, 1))
		err(1, "failed to listen on socket");

	return fd;
}

static int establish_connection(struct debug_data *data)
{
	struct epoll_event event = {
		.events = EPOLLIN | EPOLLRDHUP | EPOLLET,
		.data.ptr = data,
	};
	int client = accept4(data->sock_fd, NULL, NULL, SOCK_NONBLOCK);
	if (client < 0)
		return -EAGAIN;

	if (epoll_ctl(data->epoll_fd, EPOLL_CTL_ADD, client, &event)) {
		warn("failed to add client to epoll (%d)", client);
		close(client);
		return -EAGAIN;
	}

	pthread_mutex_lock(&data->lock);
	data->client_fd = client;
	pthread_mutex_unlock(&data->lock);

	return 0;
}

static void close_connection(struct debug_data *data)
{
	epoll_ctl(data->epoll_fd, EPOLL_CTL_DEL, data->client_fd, NULL);

	pthread_mutex_lock(&data->lock);
	shutdown(data->client_fd, SHUT_RDWR);
	close(data->client_fd);
	data->client_fd = -1;
	pthread_mutex_unlock(&data->lock);
}

static void *server_thread(void *d)
{
	struct debug_data *data = d;

	for (;;) {
		if (establish_connection(d))
			continue;

		for (;;) {
			struct epoll_event revent;
			int nevents;

			nevents = epoll_wait(data->epoll_fd, &revent, 1, -1);
			if (nevents < 0)
				err(1, "epoll_wait() failed");

			if (nevents) {
				if (revent.events & (EPOLLRDHUP | EPOLLHUP))
					break;

				if (revent.events & EPOLLIN)
					__sync_val_compare_and_swap(&data->pending, 0, 1);
			}
		}

		close_connection(data);
	}

	return NULL;
}

static struct debug_data *start_server(void)
{
	pthread_t thread;
	struct debug_data *data;

	data = calloc(1, sizeof(*data));
	if (!data)
		err(1, "failed to allocate data");

	data->sock_fd = spawn_server();
	data->epoll_fd = epoll_create(1);
	data->client_fd = -1;
	if (data->epoll_fd < 0)
		err(1, "failed to create epoll fd");
	pthread_mutex_init(&data->lock, NULL);

	if (pthread_create(&thread, NULL, server_thread, data))
		err(1, "failed to spawn server thread");

	return data;
}

static enum {
	SIM_STATE_STOPPED,
	SIM_STATE_RUNNING,
} sim_state = SIM_STATE_STOPPED;

static void handle_req(struct debug_data *debug, struct dbg_request *req,
		       struct cpu *cpu)
{
	struct dbg_response resp = { .status = req->addr > 3 ? -EINVAL : 0 };

	if (!req->read_not_write)
		debug->debug_regs[req->addr & 0x3] = req->value;

	if (req->addr == REG_CMD && !req->read_not_write) {
		switch (debug->debug_regs[REG_CMD]) {
		case CMD_STOP:
			sim_state = SIM_STATE_STOPPED;
			break;
		case CMD_RUN:
			sim_state = SIM_STATE_RUNNING;
			break;
		case CMD_STEP:
			sim_state = SIM_STATE_STOPPED;
			cpu_cycle(cpu);
			break;
		case CMD_READ_REG:
			resp.status = cpu_read_reg(cpu,
						   debug->debug_regs[REG_ADDRESS],
						   &debug->debug_regs[REG_RDATA]);
			break;
		case CMD_WRITE_REG:
			resp.status = cpu_write_reg(cpu,
						    debug->debug_regs[REG_ADDRESS],
						    debug->debug_regs[REG_WDATA]);
			break;
		case CMD_RMEM32:
			resp.status = cpu_read_mem(cpu,
						   debug->debug_regs[REG_ADDRESS],
						   &debug->debug_regs[REG_RDATA],
						   32);
			break;
		case CMD_WMEM32:
			resp.status = cpu_write_mem(cpu,
						    debug->debug_regs[REG_ADDRESS],
						    debug->debug_regs[REG_WDATA],
						    32);
			break;
		case CMD_RMEM16:
			resp.status = cpu_read_mem(cpu,
						   debug->debug_regs[REG_ADDRESS],
						   &debug->debug_regs[REG_RDATA],
						   16);
			break;
		case CMD_WMEM16:
			resp.status = cpu_write_mem(cpu,
						    debug->debug_regs[REG_ADDRESS],
						    debug->debug_regs[REG_WDATA],
						    16);
			break;
		case CMD_RMEM8:
			resp.status = cpu_read_mem(cpu,
						   debug->debug_regs[REG_ADDRESS],
						   &debug->debug_regs[REG_RDATA],
						   8);
			break;
		case CMD_WMEM8:
			resp.status = cpu_write_mem(cpu,
						    debug->debug_regs[REG_ADDRESS],
						    debug->debug_regs[REG_WDATA],
						    8);
			break;
		case CMD_RESET:
			cpu_reset(cpu);
			break;
		case CMD_SIM_TERM:
			exit(EXIT_SUCCESS);
		default:
			resp.status = -EINVAL;
		}
	}

	if (req->read_not_write)
		resp.data = debug->debug_regs[req->addr & 0x3];

	send_response(debug, &resp);
}

static void notify_runner(void)
{
	int fd;
	char *fifo_name = getenv("SIM_NOTIFY_FIFO");

	if (!fifo_name)
		return;

	fd = open(fifo_name, O_WRONLY);
	if (fd < 0)
		err(1, "failed to open notifcation fifo");

	if (write(fd, "O", 1) != 1)
		err(1, "failed to write notification byte");

	close(fd);
}

int main(int argc, char *argv[])
{
	struct cpu *cpu;
	struct debug_data *debug = start_server();
	int i, cpu_flags = CPU_NOTRACE;

	for (i = 0; i < argc; ++i)
		if (!strcmp(argv[i], "--debug") ||
		    !strcmp(argv[i], "-d"))
			cpu_flags &= ~CPU_NOTRACE;

	cpu = new_cpu(NULL, cpu_flags);

	notify_runner();

	for (;;) {
		struct dbg_request req;

		if (!debug->more_data &&
		    __sync_val_compare_and_swap(&debug->pending, 1, 0) == 0)
			debug->more_data = 1;

		if (!get_request(debug, &req))
			handle_req(debug, &req, cpu);

		if (sim_state == SIM_STATE_RUNNING)
			cpu_cycle(cpu);
	}

	return 0;
}
