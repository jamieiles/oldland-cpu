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

#include "jtag/jtag.h"

#include "../debugger/protocol.h"

struct debug_data {
	int sock_fd;
	int epoll_fd;
	int client_fd;
	int cur_ir;
};

static int get_request(struct debug_data *d, struct dbg_request *req)
{
	ssize_t br;
	int rc = -EAGAIN;

	if (d->client_fd < 0)
		goto out;

	br = read(d->client_fd, req, sizeof(*req));
	rc = br > 0 ? 0 : -EIO;

out:
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

	if (jtag_open_virtual_device(0x00))
		err(1, "failed to open virtual device");

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

	data->client_fd = client;

	return 0;
}

static void close_connection(struct debug_data *data)
{
	epoll_ctl(data->epoll_fd, EPOLL_CTL_DEL, data->client_fd, NULL);

	shutdown(data->client_fd, SHUT_RDWR);
	close(data->client_fd);
	data->client_fd = -1;
}

static int set_vir(struct debug_data *debug, int ir)
{
	int rc = 0;

	if (debug->cur_ir != ir)
		rc = jtag_vir(ir);
	debug->cur_ir = ir;

	return rc;
}

/* Wait for the current operation to finish. */
static int wait_complete(struct debug_data *debug)
{
	int rc = 0;
	unsigned result;

	do {
		if (set_vir(debug, 0x4) || jtag_vdr(32, 0, &result)) {
			rc = -EIO;
			break;
		}
	} while (result & 0x1);

	return rc;
}

static int handle_req(struct debug_data *debug, struct dbg_request *req)
{
	struct dbg_response resp = { .status = req->addr > 3 ? -EINVAL : 0 };
	uint32_t addr = req->addr;
	unsigned out;

	if (!req->read_not_write) {
		addr |= (1 << 3); /* Write enable. */

		if (set_vir(debug, addr) || jtag_vdr(32, req->value, &out)) {
			warnx("failed to write request");
			return -EIO;
		}

		if (wait_complete(debug)) {
			warnx("failed to complete request");
			return -EIO;
		}
	} else {
		if (set_vir(debug, addr) || jtag_vdr(32, 0, &out)) {
			warnx("failed to perform read");
			return -EIO;
		}

		if (wait_complete(debug)) {
			warnx("failed to complete read request");
			return -EIO;
		}
	}

	resp.data = out;

	send_response(debug, &resp);

	return 0;
}

static void server_loop(struct debug_data *d)
{
	for (;;) {
		if (establish_connection(d))
			continue;

		for (;;) {
			struct epoll_event revent;
			struct dbg_request req;
			int nevents;

			nevents = epoll_wait(d->epoll_fd, &revent, 1, -1);
			if (nevents < 0)
				err(1, "epoll_wait() failed");

			if (nevents) {
				if (revent.events & (EPOLLRDHUP | EPOLLHUP))
					break;

				if (!get_request(d, &req) &&
				    handle_req(d, &req))
					break;
			}
		}

		close_connection(d);
	}
}

static struct debug_data *start_server(void)
{
	struct debug_data *data;

	data = calloc(1, sizeof(*data));
	if (!data)
		err(1, "failed to allocate data");

	data->cur_ir = -1;
	data->sock_fd = spawn_server();
	data->epoll_fd = epoll_create(1);
	data->client_fd = -1;
	if (data->epoll_fd < 0)
		err(1, "failed to create epoll fd");

	return data;
}

int main(int argc, char *argv[])
{
	struct debug_data *debug = start_server();

	for (;;)
		server_loop(debug);

	return 0;
}
