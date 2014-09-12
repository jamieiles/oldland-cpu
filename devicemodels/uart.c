#define _GNU_SOURCE

#include <assert.h>
#include <err.h>
#include <errno.h>
#include <fcntl.h>
#include <poll.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <termios.h>
#include <unistd.h>

#include "uart.h"

int create_pts(void)
{
	int pts = posix_openpt(O_RDWR | O_NONBLOCK);
	struct termios termios;

	if (pts < 0)
		err(1, "failed to create pseudo terminal");

	if (grantpt(pts))
		err(1, "failed to grant psuedo terminal access");

	if (unlockpt(pts))
		err(1, "failed to unlock pseudo terminal");

	if (tcgetattr(pts, &termios))
		err(1, "failed to get termios");
	cfmakeraw(&termios);
	if (tcsetattr(pts, TCSANOW, &termios))
		err(1, "failed to set termios");

	if (sim_is_interactive())
		printf("pts: %s\n", ptsname(pts));

	return pts;
}

