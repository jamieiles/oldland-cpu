#define _GNU_SOURCE
#include <errno.h>
#include <fcntl.h>
#include <netdb.h>
#include <pthread.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

#include <sys/epoll.h>
#include <sys/uio.h>
#include <sys/socket.h>
#include <sys/types.h>

#include "../debugger/protocol.h"
#include "../common/die.h"
#include "jtag.h"

int get_request(struct jtag_debug_data *d, struct dbg_request *req)
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

int send_response(struct jtag_debug_data *d, const struct dbg_response *resp)
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
		die("failed to enable SO_REUSEADDR");
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
		die("getaddrinfo failed");

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
		die("failed to bind server");

	freeaddrinfo(result);

	if (listen(fd, 1))
		die("failed to listen on socket");

	return fd;
}

static int establish_connection(struct jtag_debug_data *data)
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

static void close_connection(struct jtag_debug_data *data)
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
	struct jtag_debug_data *data = d;

	for (;;) {
		if (establish_connection(d))
			continue;

		for (;;) {
			struct epoll_event revent;
			int nevents;

			nevents = epoll_wait(data->epoll_fd, &revent, 1, -1);
			if (nevents < 0)
				die("epoll_wait() failed");

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

struct jtag_debug_data *start_server(void)
{
	pthread_t thread;
	struct jtag_debug_data *data;

	data = calloc(1, sizeof(*data));
	if (!data)
		die("failed to allocate data");

	data->sock_fd = spawn_server();
	data->epoll_fd = epoll_create(1);
	data->client_fd = -1;
	if (data->epoll_fd < 0)
		die("failed to create epoll fd");
	pthread_mutex_init(&data->lock, NULL);

	if (pthread_create(&thread, NULL, server_thread, data))
		die("failed to spawn server thread");

	return data;
}

void notify_runner(void)
{
	int fd;
	char *fifo_name = getenv("SIM_NOTIFY_FIFO");

	if (!fifo_name)
		return;

	fd = open(fifo_name, O_WRONLY);
	if (fd < 0)
		die("failed to open notifcation fifo");

	if (write(fd, "O", 1) != 1)
		die("failed to write notification byte");

	close(fd);
}

