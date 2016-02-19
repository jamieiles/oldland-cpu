#define _GNU_SOURCE

#include <assert.h>
#include <errno.h>
#include <fcntl.h>
#include <poll.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <termios.h>
#include <unistd.h>

#include "uart.h"
#include "../common/die.h"

int create_pts(void)
{
	int pts = posix_openpt(O_RDWR | O_NONBLOCK);
	struct termios termios;

	if (pts < 0)
		die("failed to create pseudo terminal");

	if (grantpt(pts))
		die("failed to grant psuedo terminal access");

	if (unlockpt(pts))
		die("failed to unlock pseudo terminal");

	if (tcgetattr(pts, &termios))
		die("failed to get termios");
	cfmakeraw(&termios);
	if (tcsetattr(pts, TCSANOW, &termios))
		die("failed to set termios");

	if (sim_is_interactive())
		printf("pts: %s\n", ptsname(pts));

	return pts;
}

