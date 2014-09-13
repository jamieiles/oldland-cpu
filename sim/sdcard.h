#ifndef __SDCARD_H__
#define __SDCARD_H__

#include "spimaster.h"

struct spislave *sdcard_new(const char *sdcard_image);

#endif /* __SDCARD_H__ */
