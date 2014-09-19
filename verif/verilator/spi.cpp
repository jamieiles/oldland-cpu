#include <cassert>
#include <string>
#include <verilated.h>
#include "../../devicemodels/spi_sdcard.h"

static struct spi_sdcard *sdcard;

static const std::string get_sdcard_path()
{
	std::string sdcard = Verilated::commandArgsPlusMatch("sdcard=");

	if (sdcard == "")
		return "";

	return sdcard.substr(sdcard.find("=") + 1);
}

void init_spi()
{
	std::string path = get_sdcard_path();

	if (path == "")
		return;

	sdcard = spi_sdcard_new(path.c_str());
	assert(sdcard != NULL);
}

void spi_rx_byte_from_master(IData cs, CData val)
{
	switch (cs) {
	case 0:
		if (sdcard)
			spi_sdcard_next_byte_to_slave(sdcard, val);
		break;
	default:
		break;
	}
}

void spi_get_next_byte_to_master(IData cs, CData *val)
{
	*val = 0;

	switch (cs) {
	case 0:
		if (sdcard)
			*val = spi_sdcard_next_byte_to_master(sdcard);
		break;
	default:
		break;
	}
}
