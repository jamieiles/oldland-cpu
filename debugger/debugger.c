#define _GNU_SOURCE

#include <assert.h>
#include <err.h>
#include <errno.h>
#include <fcntl.h>
#include <netdb.h>
#include <signal.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

#include <sys/socket.h>
#include <sys/types.h>
#include <sys/uio.h>

#include <readline/readline.h>
#include <readline/history.h>

#include <lua5.2/lua.h>
#include <lua5.2/lauxlib.h>
#include <lua5.2/lualib.h>

#include "debugger.h"
#include "protocol.h"

#ifndef INSTALL_PATH
#define INSTALL_PATH "/usr/local"
#endif /* !INSTALL_PATH */

struct target {
	int fd;
	bool interrupted;
};

static struct target *target;

const struct target *get_target(void)
{
	return target;
}

static void sigint_handler(int s)
{
	target->interrupted = true;
}

static int target_exchange(const struct target *t,
			   const struct dbg_request *req,
			   struct dbg_response *resp)
{
	ssize_t rc;
	struct iovec reqv = {
		.iov_base = (void *)req,
		.iov_len = sizeof(*req)
	};
	struct iovec respv = {
		.iov_base = resp,
		.iov_len = sizeof(*resp)
	};

	rc = writev(t->fd, &reqv, 1);
	if (rc < 0)
		return -EIO;
	if (rc != (ssize_t)sizeof(*req))
		return -EIO;

	rc = readv(t->fd, &respv, 1);
	if (rc < 0)
		return rc;
	if (rc != (ssize_t)sizeof(*resp))
		return -EIO;

	return 0;
}

static int dbg_write(const struct target *t, enum dbg_reg addr, uint32_t value)
{
	struct dbg_request req = {
		.addr = addr,
		.value = value,
		.read_not_write = 0,
	};
	struct dbg_response resp;
	int rc;

	rc = target_exchange(t, &req, &resp);
	if (!rc)
		rc = resp.status;

	return rc;
}

static int dbg_read(const struct target *t, enum dbg_reg addr, uint32_t *value)
{
	struct dbg_request req = {
		.addr = addr,
		.read_not_write = 1,
	};
	struct dbg_response resp;
	int rc;

	rc = target_exchange(t, &req, &resp);
	if (!rc)
		rc = resp.status;
	*value = resp.data;

	return rc;
}

int dbg_stop(const struct target *t)
{
	return dbg_write(t, REG_CMD, CMD_STOP);
}

int dbg_run(const struct target *t)
{
	return dbg_write(t, REG_CMD, CMD_RUN);
}

int dbg_step(const struct target *t)
{
	return dbg_write(t, REG_CMD, CMD_STEP);
}

int dbg_read_reg(const struct target *t, unsigned reg, uint32_t *val)
{
	int rc;

	rc = dbg_write(t, REG_ADDRESS, reg);
	if (rc)
		return rc;
	rc = dbg_write(t, REG_CMD, CMD_READ_REG);
	if (rc)
		return rc;

	return dbg_read(t, REG_RDATA, val);
}

#define MEM_READ_FN(width)							\
int dbg_read##width(const struct target *t, unsigned addr, uint32_t *val)	\
{										\
	int rc;									\
										\
	rc = dbg_write(t, REG_ADDRESS, addr);					\
	if (rc)									\
		return rc;							\
	rc = dbg_write(t, REG_CMD, CMD_RMEM##width);				\
	if (rc)									\
		return rc;							\
										\
	return dbg_read(t, REG_RDATA, val);					\
}										\
										\
static int lua_read##width(lua_State *L)					\
{										\
	uint32_t v;								\
	lua_Integer addr;							\
										\
	addr = lua_tointeger(L, 1);						\
	if (dbg_read##width(target, addr, &v))					\
		warnx("failed to read " #width "-bit address %u",		\
		      (unsigned)addr);						\
	lua_pop(L, 1);								\
	lua_pushinteger(L, v);							\
										\
	return 1;								\
}

#define MEM_WRITE_FN(width)							\
int dbg_write##width(const struct target *t, unsigned addr, uint32_t val)	\
{										\
	int rc;									\
										\
	rc = dbg_write(t, REG_ADDRESS, addr);					\
	if (rc)									\
		return rc;							\
	rc = dbg_write(t, REG_WDATA, val);					\
	if (rc)									\
		return rc;							\
										\
	return dbg_write(t, REG_CMD, CMD_WMEM##width);				\
}										\
										\
static int lua_write##width(lua_State *L)					\
{										\
	lua_Integer addr, val;							\
										\
	addr = lua_tointeger(L, 1);						\
	val = lua_tointeger(L, 2);						\
	if (dbg_write##width(target, addr, val))				\
		warnx("failed to write " #width "-bit address  %u",		\
		      (unsigned)addr);						\
	lua_pop(L, 2);								\
										\
	return 0;								\
}

MEM_READ_FN(32);
MEM_READ_FN(16);
MEM_READ_FN(8);
MEM_WRITE_FN(32);
MEM_WRITE_FN(16);
MEM_WRITE_FN(8);

int dbg_write_reg(const struct target *t, unsigned reg, uint32_t val)
{
	int rc;

	rc = dbg_write(t, REG_ADDRESS, reg);
	if (rc)
		return rc;
	rc = dbg_write(t, REG_WDATA, val);
	if (rc)
		return rc;

	return dbg_write(t, REG_CMD, CMD_WRITE_REG);
}

int open_server(const char *hostname, const char *port)
{
	struct addrinfo *result, *rp, hints = {
		.ai_family	= AF_INET,
		.ai_socktype	= SOCK_STREAM,
	};
	int s, fd;

	s = getaddrinfo(hostname, port, &hints, &result);
	if (s)
		return -errno;

	for (rp = result; rp != NULL; rp = rp->ai_next) {
		fd = socket(rp->ai_family, rp->ai_socktype, rp->ai_protocol);
		if (fd < 0)
			continue;
		if (connect(fd, rp->ai_addr, rp->ai_addrlen) >= 0)
			break;
		close(fd);
	}

	freeaddrinfo(result);

	if (!rp)
		return -EADDRNOTAVAIL;

	return fd;
}

static struct target *target_alloc(void)
{
	struct target *t = calloc(1, sizeof(*t));

	if (!t)
		err(1, "failed to allocate target");

	t->fd = open_server("localhost", "36000");
	if (t->fd < 0)
		err(1, "failed to connect to server");

	return t;
}

static int lua_step(lua_State *L)
{
	if (dbg_step(target))
		warnx("failed to step target");

	return 0;
}

static int lua_stop(lua_State *L)
{
	if (dbg_stop(target))
		warnx("failed to step target");

	return 0;
}

static void wait_until_stopped(struct target *t)
{
	target->interrupted = false;

	while (!target->interrupted)
		pause();
}

static int lua_run(lua_State *L)
{
	if (dbg_run(target))
		warnx("failed to step target");

	wait_until_stopped(target);

	return 0;
}

static int lua_read_reg(lua_State *L)
{
	uint32_t v;
	lua_Integer regnum;

	regnum = lua_tointeger(L, 1);
	if (dbg_read_reg(target, regnum, &v))
		warnx("failed to read register %u", (unsigned)regnum);
	lua_pop(L, 1);
	lua_pushinteger(L, v);

	return 1;
}

static int lua_write_reg(lua_State *L)
{
	lua_Integer regnum, val;

	regnum = lua_tointeger(L, 1);
	val = lua_tointeger(L, 2);
	if (dbg_write_reg(target, regnum, val))
		warnx("failed to write register %u", (unsigned)regnum);
	lua_pop(L, 2);

	return 0;
}

static int lua_loadelf(lua_State *L)
{
	const char *path;

	path = lua_tostring(L, 1);
	if (load_elf(target, path))
		warnx("failed to load device with %s", path);
	lua_pop(L, 1);

	return 0;
}

static const struct luaL_Reg dbg_funcs[] = {
	{ "step", lua_step },
	{ "run", lua_run },
	{ "stop", lua_stop },
	{ "read_reg", lua_read_reg },
	{ "write_reg", lua_write_reg },
	{ "read32", lua_read32 },
	{ "write32", lua_write32 },
	{ "read16", lua_read16 },
	{ "write16", lua_write16 },
	{ "read8", lua_read8 },
	{ "write8", lua_write8 },
	{ "loadelf", lua_loadelf },
	{}
};

static void load_support(lua_State *L)
{
	char *path = NULL;

	if (asprintf(&path, "%s/libexec/oldland-debug-ui.lua",
		     INSTALL_PATH) < 0)
		err(1, "failed to allocate support path");

	if (luaL_dofile(L, path))
		errx(1, "failed to load support (%s)", lua_tostring(L, -1));

	free(path);
}

int main(void)
{
	lua_State *L = luaL_newstate();

	assert(L);

	luaL_openlibs(L);
	luaL_newlib(L, dbg_funcs);
	lua_setglobal(L, "target");
	load_support(L);

	target = target_alloc();

	stifle_history(1024);

	signal(SIGINT, sigint_handler);

	for (;;) {
		char *line = readline("oldland> ");

		if (!line)
			break;

		if (luaL_dostring(L, line))
			warnx("error: %s", lua_tostring(L, -1));

		add_history(line);
	}

	return 0;
}
