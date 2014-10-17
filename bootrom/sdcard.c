#include "common.h"
#include "uart.h"
#include "string.h"

#define SD_CLK_DIVIDER	0x1ff
#define SD_FAST_DIVIDER	0x002
#define SD_NCR		8
#define SD_CS		1
/* Maximum number of high bytes to read before a data start token. */
#define MAX_DATA_START_OFFS 512

#define SPI_CTRL_REG		0x0
#define SPI_CS_ENABLE_REG	0x1
#define SPI_XFER_CTRL_REG	0x2
#define SPI_XFER_BUF_OFFS	8192
#define SPI_BASE_ADDRESS	0x80004000

#define XFER_START		(1 << 16)
#define XFER_BUSY		(1 << 17)

#define DATA_START_TOKEN	0xfe
#define BLOCK_SIZE		512

/*
 * Load into the middle of SDRAM, this should be flexible enough for ELF files
 * that want to run in the bottom or top of SDRAM.
 */
static void *load_buffer = (void *)(0x20000000 + (16 * 1024 * 1024));
#define LOAD_BUFFER_SIZE (16 * 1024 * 1024)

typedef unsigned char uint8_t;
typedef unsigned short uint16_t;
typedef unsigned long uint32_t;
typedef unsigned long long uint64_t;
typedef signed char int8_t;
typedef signed short int16_t;
typedef signed long int32_t;
typedef signed long long int64_t;

#include "elf.h"

struct elf_info {
	const void *elf;
	const Elf32_Ehdr *ehdr;
	const Elf32_Shdr *shdrs;
	const Elf32_Phdr *phdrs;
	const char *secstrings;
};

#define for_each_phdr(phdr, elf) \
	for ((phdr) = (elf)->phdrs; \
	     (phdr) < (elf)->phdrs + (elf)->ehdr->e_phnum; \
	     (phdr)++)

static volatile unsigned char *spi_cmd_buf =
	(volatile unsigned char *)(SPI_BASE_ADDRESS + SPI_XFER_BUF_OFFS);

struct spi_cmd {
	unsigned char cmd;
	unsigned char arg[4];
	unsigned char crc;

	const unsigned char *data;
	unsigned long tx_datalen;
	unsigned long rx_datalen;
};

struct r1_response {
	unsigned char v;
};

#define R1_ERROR_MASK 0xfe

static void spi_write_reg(unsigned int regnum, unsigned long val)
{
	volatile unsigned long *base = (volatile unsigned long *)SPI_BASE_ADDRESS;

	base[regnum] = val;
}

static unsigned long spi_read_reg(unsigned int regnum)
{
	volatile unsigned long *base = (volatile unsigned long *)SPI_BASE_ADDRESS;

	return base[regnum];
}

static void spi_wait_idle(void)
{
	unsigned long xfer_ctrl;

	do {
		xfer_ctrl = spi_read_reg(SPI_XFER_CTRL_REG);
	} while (xfer_ctrl & XFER_BUSY);
}

static void send_initial_clock(void)
{
	unsigned m;

	for (m = 0; m < 80 / 10; ++m)
		spi_cmd_buf[m] = 0xff;

	spi_write_reg(SPI_CTRL_REG, SD_CLK_DIVIDER);
	spi_write_reg(SPI_CS_ENABLE_REG, 0);
	spi_write_reg(SPI_XFER_CTRL_REG, XFER_START | (80 / 10));
	spi_wait_idle();
}

static void flush_fifo(void)
{
	unsigned m;

	for (m = 0; m < 128; ++m)
		spi_cmd_buf[m] = 0xff;

	spi_write_reg(SPI_CTRL_REG, SD_CLK_DIVIDER);
	spi_write_reg(SPI_CS_ENABLE_REG, SD_CS);
	spi_write_reg(SPI_XFER_CTRL_REG, XFER_START | 128);
	spi_wait_idle();
}

static void spi_do_command(const struct spi_cmd *cmd)
{
	unsigned long m, cmdlen;

	cmdlen = 1 + 6 + cmd->tx_datalen + cmd->rx_datalen + SD_NCR;

	/* The command. */
	spi_cmd_buf[0] = 0xff;

	spi_cmd_buf[1] = cmd->cmd;
	for (m = 0; m < 4; ++m)
		spi_cmd_buf[2 + m] = cmd->arg[m];
	spi_cmd_buf[6] = cmd->crc;
	/* Transmit data. */
	for (m = 0; m < cmd->tx_datalen; ++m)
		spi_cmd_buf[7 + m] = cmd->data[m];
	/* Initialize receive buffer so we don't shift out new, garbage data. */
	for (m = 7 + cmd->tx_datalen; m < cmdlen; ++m)
		spi_cmd_buf[m] = 0xff;

	spi_write_reg(SPI_CS_ENABLE_REG, SD_CS);
	spi_write_reg(SPI_XFER_CTRL_REG, XFER_START | cmdlen);
	spi_wait_idle();
}

static const volatile unsigned char *find_r1_response(struct r1_response *r1)
{
	const volatile unsigned char *p = spi_cmd_buf + 7;

	r1->v = 0;
	while (p < (const volatile unsigned char *)0x80008000 && *p == 0xff)
		++p;

	if (p == (const volatile unsigned char *)0x80008000)
		return NULL;

	r1->v = *p;

	return p;
}

static int send_reset(void)
{
	struct spi_cmd cmd = {
		.cmd = 0x40,
		.crc = 0x95,
		.rx_datalen = 1,
	};
	struct r1_response r1;

	spi_do_command(&cmd);
	if (!find_r1_response(&r1))
		return -1;

	return r1.v & R1_ERROR_MASK;
}

static int send_if_cond(void)
{
	struct spi_cmd cmd = {
		.cmd = 0x48,
		.crc = 0x87,
		.arg = { 0x00, 0x00, 0x01, 0xaa },
		.rx_datalen = 1,
	};
	struct r1_response r1;

	spi_do_command(&cmd);
	if (!find_r1_response(&r1))
		return -1;

	return r1.v & R1_ERROR_MASK;
}

static int send_read_ocr(void)
{
	struct spi_cmd cmd = {
		.cmd = 0x7a,
		.rx_datalen = 5,
	};
	struct r1_response r1;

	spi_do_command(&cmd);
	if (!find_r1_response(&r1))
		return -1;

	return r1.v & R1_ERROR_MASK;
}

static int send_acmd(void)
{
	struct spi_cmd cmd = {
		.cmd = 0x77,
		.arg = { 0x00, 0x00, 0x00, 0x00 },
		.rx_datalen = 1,
	};
	struct r1_response r1;

	spi_do_command(&cmd);
	if (!find_r1_response(&r1))
		return -1;

	return r1.v & R1_ERROR_MASK;
}

static int sd_wait_ready(void)
{
	struct r1_response r1 = {};

	do {
		struct spi_cmd cmd = {
			.cmd = 0x69,
			.arg = { 0x40, 0x00, 0x00, 0x00 },
			.rx_datalen = 1,
		};
		int rc = send_acmd();

		if (rc)
			return rc;

		spi_do_command(&cmd);
		if (!find_r1_response(&r1))
			return -1;

		if (r1.v & R1_ERROR_MASK)
			return r1.v & R1_ERROR_MASK;
	} while (r1.v & 0x1);

	return 0;
}

static int sd_set_blocklen(void)
{
	struct spi_cmd cmd = {
		.cmd = 0x50,
		/* BLOCK_SIZE bytes */
		.arg = { 0x00, 0x00, 0x02, 0x00 },
		.rx_datalen = 1,
	};
	struct r1_response r1;

	spi_do_command(&cmd);
	if (!find_r1_response(&r1))
		return -1;

	return r1.v & R1_ERROR_MASK;
}

static const volatile unsigned char *
find_data_start(const volatile unsigned char *r1ptr)
{
	++r1ptr;

	while (*r1ptr != DATA_START_TOKEN)
		++r1ptr;

	return r1ptr + 1;
}

static void copy_block(unsigned char *dst, const volatile unsigned char *src)
{
	unsigned m;

	for (m = 0; m < BLOCK_SIZE; ++m)
		dst[m] = src[m];
}

static int assert_partitioned(const unsigned char *mbr)
{
	if (mbr[0x1fe] != 0x55 && mbr[0x1ff] != 0xaa) {
		putstr("ERROR: card not partitioned, no MBR\n");
		return -1;
	}

	return 0;
}

struct partition_entry {
	unsigned char status;
	unsigned char chs_start[3];

	unsigned char type;
	unsigned char chs_end[3];

	union {
		unsigned char first_lba_bytes[4];
		unsigned long first_lba;
	};

	union {
		unsigned char num_sectors_bytes[4];
		unsigned long num_sectors;
	};
};

static void get_active_partition(const unsigned char *mbr,
				 unsigned long *start, unsigned long *size)
{
	int rc;
	unsigned m;

	rc = assert_partitioned(mbr);
	if (rc)
		return;

	for (m = 0; m < 4; ++m) {
		struct partition_entry pe;

		memcpy(&pe, mbr + 0x1be + (m * sizeof(pe)), sizeof(pe));

		if (pe.type == 0 || !pe.status)
			continue;

		*start = pe.first_lba;
		*size = pe.num_sectors * 512;
	}
}

static int read_sector(unsigned long address, unsigned char *dst)
{
	struct spi_cmd cmd = {
		.cmd = 0x51,
		.arg = { (address >> 24) & 0xff,
			 (address >> 16) & 0xff,
			 (address >> 8)  & 0xff,
			 (address >> 0)  & 0xff
		},
		/* r1, start token, data, CRC16 */
		.rx_datalen = 1 + 1 + BLOCK_SIZE + 2 + MAX_DATA_START_OFFS,
	};
	struct r1_response r1;
	const volatile unsigned char *r1ptr, *data_start;

	uart_putc('#');

	spi_write_reg(SPI_CTRL_REG, SD_FAST_DIVIDER);

	spi_do_command(&cmd);
	r1ptr = find_r1_response(&r1);
	if (!r1ptr) {
		putstr("failed to find r1 response\n");
		return -1;
	}
	if (r1.v & R1_ERROR_MASK) {
		putstr("read sector failed\n");
		return -1;
	}

	data_start = find_data_start(r1ptr);
	copy_block(dst, data_start);

	return 0;
}

static void find_boot_partition(unsigned long *start, unsigned long *size)
{
	static unsigned char mbr[BLOCK_SIZE];

	read_sector(0, mbr);
	get_active_partition(mbr, start, size);
}

static int get_boot_partition_address(unsigned long *start,
				      unsigned long *size)
{
	int rc;

	send_initial_clock();
	flush_fifo();
	rc = send_reset();
	if (rc) {
		putstr("readmbr: failed to reset\n");
		return -1;
	}
	rc = send_if_cond();
	if (rc) {
		putstr("readmbr: failed to send interface conditions\n");
		return -1;
	}
	rc = send_read_ocr();
	if (rc)
		putstr("readmbr: warning: unable to read OCR\n");
	rc = sd_wait_ready();
	if (rc)
		putstr("readmbr: warning: failed to wait for SD to become ready\n");

	rc = sd_set_blocklen();
	if (rc) {
		putstr("readmbr: failed to set blocklen\n");
		return -1;
	}

	find_boot_partition(start, size);

	return 0;
}

enum fat_ver {
	FAT12,
	FAT16,
	FAT32,
};

struct fat_superblock {
	unsigned long	partition_lba;
	unsigned short	bytes_per_sector;
	unsigned char	sectors_per_cluster;
	unsigned short	reserved_sectors;
	unsigned char	nr_fats;
	unsigned short	max_root_dirents;
	unsigned long	total_sectors;
	unsigned short	sectors_per_fat;
	unsigned char	fat_bits;
	char		oem_name[9];
	enum fat_ver	version;
	unsigned long	eoc_marker;
};

#define FAT_DIRENT_F_RO		(1 << 0)
#define FAT_DIRENT_F_HIDDEN	(1 << 1)
#define FAT_DIRENT_F_SYSTEM	(1 << 2)
#define FAT_DIRENT_F_VOLLABEL	(1 << 3)
#define FAT_DIRENT_F_SUBDIR	(1 << 4)
#define FAT_DIRENT_F_ARCHIVE	(1 << 5)
#define FAT_DIRENT_F_DEVICE	(1 << 6)

struct fat_dirent {
	unsigned short		name[256];
	char		ext[4];
	unsigned char	flags;
	unsigned short	first_cluster;
	unsigned long	size;
};

static inline int fat_dirent_is_dir(const struct fat_dirent *d)
{
	return d->flags & FAT_DIRENT_F_SUBDIR;
}

static inline unsigned char fat_read8(const unsigned char *p)
{
	return *p;
}

static inline unsigned short fat_read16(const unsigned char *p)
{
	return *p | (*(p + 1) << 8);
}

static inline unsigned long fat_read32(const unsigned char *p)
{
	return *p | (*(p + 1) << 8) | (*(p + 2) << 16) | (*(p + 3) << 24);
}

static int sd_read(const struct fat_superblock *sb, void *dst, unsigned len,
		   unsigned long offset)
{
	static unsigned char sector_buf[512];
	unsigned bytes_read = 0;

	while (bytes_read < len) {
		unsigned sector_num = (offset / 512) + sb->partition_lba;
		unsigned sector_offset = offset % 512;
		unsigned bytes_to_sector_end = 512 - sector_offset;
		unsigned long bytes_remaining = len - bytes_read;
		unsigned read_len = bytes_to_sector_end < bytes_remaining ?
			bytes_to_sector_end : bytes_remaining;

		if (read_sector(sector_num * 512, sector_buf))
			return -1;

		memcpy(dst + bytes_read, sector_buf + sector_offset, read_len);

		bytes_read += read_len;
		offset += read_len;
	}

	return 0;
}

static unsigned long fat_read_entry(const struct fat_superblock *sb, unsigned long entry)
{
	unsigned long val, fat_byte_addr = (entry * sb->fat_bits) / 8;
	unsigned bit_offs = (entry * sb->fat_bits) % 8;
	unsigned long fat_addr = sb->reserved_sectors * sb->bytes_per_sector;

	sd_read(sb, &val, sizeof(val), fat_byte_addr + fat_addr);

	val >>= bit_offs;
	val &= ((1 << sb->fat_bits) - 1);

	return val;
}

static void fat_decode_boot_sect(const unsigned char *hdr,
				 struct fat_superblock *sb)
{
	unsigned long nr_clusters;

	sb->bytes_per_sector = fat_read16(hdr + 0xb);
	sb->sectors_per_cluster = fat_read8(hdr + 0xd);
	sb->reserved_sectors = fat_read16(hdr + 0xe);
	sb->nr_fats = fat_read8(hdr + 0x10);
	sb->max_root_dirents = fat_read16(hdr + 0x11);
	sb->sectors_per_fat = fat_read16(hdr + 0x16);

	sb->total_sectors = fat_read16(hdr + 0x13);
	if (!sb->total_sectors)
		sb->total_sectors = fat_read32(hdr + 0x20);
	nr_clusters = sb->total_sectors / sb->sectors_per_cluster;

	if (nr_clusters < 4085) {
		sb->version = FAT12;
		sb->fat_bits = 12;
	} else if (nr_clusters < 65525) {
		sb->version = FAT16;
		sb->fat_bits = 16;
	} else {
		sb->version = FAT32;
		sb->fat_bits = 32;
	}

	sb->eoc_marker = fat_read_entry(sb, 1);

	memcpy(sb->oem_name, hdr + 0x3, 8);
	sb->oem_name[8] = '\0';
}

static unsigned long fat_root_dir_offs(const struct fat_superblock *sb)
{
	return (sb->reserved_sectors + (sb->nr_fats * sb->sectors_per_fat)) *
		sb->bytes_per_sector;
}

static inline int fat_is_lfn(const struct fat_dirent *dirent)
{
	return (dirent->flags & 0x0f) == 0x0f;
}

static void fat_read_wchar(unsigned short *dst, const char *src, unsigned long nr_wchar)
{
	while (nr_wchar--) {
		*dst++ = (*src | (*(src + 1) << 8));
		src += 2;
	}
}

static void fat_read_lfn(const struct fat_superblock *sb,
			 struct fat_dirent *dirent, unsigned nr_lfn_ents,
			 unsigned long offs)
{
	char buf[32];
	unsigned long pos = offs + (nr_lfn_ents - 1) * 32;
	unsigned long idx = 0;

	do {
		if (sd_read(sb, buf, sizeof(buf), pos))
			return;

		fat_read_wchar(dirent->name + idx + 0, buf + 0x01, 5);
		fat_read_wchar(dirent->name + idx + 5, buf + 0x0e, 6);
		fat_read_wchar(dirent->name + idx + 11, buf + 0x1c, 2);

		pos -= 32;
		idx += 13;

	} while (pos >= offs);
}

static char *strnchr(char *str, unsigned long len, int c)
{
	unsigned long n;

	for (n = 0; n < len; ++n)
		if (str[n] == c)
			return str + n;

	return NULL;
}

static void fat_read_shortname(struct fat_dirent *dirent, unsigned long offs,
			       const unsigned char buf[32])
{
	char name[9];
	char ext[4];
	unsigned short *lstr = dirent->name;
	char *p;

	memcpy(name, buf + 0x00, 8);
	if (strnchr(name, 9, ' '))
		*strnchr(name, 9, ' ') = '\0';
	name[8] = '\0';
	memcpy(ext, buf + 0x08, 3);
	if (strnchr(ext, 4, ' '))
		*strnchr(ext, 4, ' ') = '\0';
	ext[3] = '\0';

	p = name;
	while (*p)
		*lstr++ = *p++;

	*lstr++ = '.';

	p = ext;
	while (*p)
		*lstr++ = *p++;
}

static int fat_get_next_dirent(const struct fat_superblock *sb,
			       unsigned char *buf, unsigned long *offs)
{
	for (;;) {
		if (sd_read(sb, buf, 32, *offs)) {
			putstr("failed to read\n");
			return -1;
		}

		if (buf[0] == 0)
			return -1;

		if (buf[0] != 0xe5)
			break;

		*offs += 32;
	}

	return 0;
}

static void fat_read_name(const struct fat_superblock *sb,
			  struct fat_dirent *dirent, unsigned nr_lfn_ents,
			  unsigned long offs, unsigned char *buf)
{
	if (fat_is_lfn(dirent))
		fat_read_lfn(sb, dirent, nr_lfn_ents, offs);
	else
		fat_read_shortname(dirent, offs, buf);
}

static int fat_read_dirent(const struct fat_superblock *sb,
			   struct fat_dirent *dirent, unsigned long *offs)
{
	unsigned char buf[32];
	unsigned nr_lfn_ents;
	unsigned long pos;
	int ret;

	ret = fat_get_next_dirent(sb, buf, offs);
	if (ret == -1)
		return ret;

	dirent->flags = buf[0x0b];
	nr_lfn_ents = fat_is_lfn(dirent) ? buf[0] & 0x3f : 0;

	pos = *offs + 32 * nr_lfn_ents;
	if (sd_read(sb, buf, sizeof(buf), pos)) {
		putstr("failed to read directory entry\n");
		return -1;
	}

	dirent->flags = buf[0x0b];
	dirent->first_cluster = fat_read16(buf + 0x1a);
	dirent->size = fat_read32(buf + 0x1c);
	fat_read_name(sb, dirent, nr_lfn_ents, *offs, buf);

	if (buf[0] == 0) {
		putstr("name invalid\n");
		return -1;
	}

	*offs = pos + 32;

	return 0;
}

static unsigned long fat_read_from_cluster(const struct fat_superblock *sb,
				     void *dst, unsigned long cluster, unsigned long len)
{
	unsigned long cluster_addr = 0;
	unsigned long data_sector_base;

	data_sector_base =
		(sb->reserved_sectors + sb->nr_fats * sb->sectors_per_fat);

	if (sb->version != FAT32)
		data_sector_base += ((sb->max_root_dirents * 32) /
				     sb->bytes_per_sector);

	/*
	 * Clusters 0&1 are reserved so we start from cluster 2, hence the -2.
	 */
	cluster_addr = data_sector_base * sb->bytes_per_sector + (cluster - 2) *
		sb->sectors_per_cluster * sb->bytes_per_sector;
	if (sd_read(sb, dst, len, cluster_addr)) {
		putstr("failed to read from cluster\n");
		return 0;
	}

	return len;
}

static unsigned long fat_read_buf(const struct fat_superblock *sb,
			    const struct fat_dirent *dirent, void *dst,
			    unsigned long len, unsigned offs)
{
	unsigned long cluster = dirent->first_cluster;
	unsigned long pos = 0, copied = 0;
	unsigned long bytes_per_cluster = sb->bytes_per_sector * sb->sectors_per_cluster;

	while (len > 0) {
		if (pos >= offs) {
			unsigned long cluster_offs = offs % bytes_per_cluster;
			unsigned long clen = bytes_per_cluster - cluster_offs;

			if (clen > len)
				clen = len;
			if (clen > bytes_per_cluster)
				clen = bytes_per_cluster;

			fat_read_from_cluster(sb, dst + copied, cluster, clen);

			offs += cluster_offs;
			copied += clen;
			len -= clen;
		}

		cluster = fat_read_entry(sb, cluster);
		if (cluster == sb->eoc_marker)
			break;

		pos += bytes_per_cluster;
	}

	return 0;
}

static void load_elf(const void *buf)
{
	struct elf_info info = {
		.elf = buf,
	};
	const Elf32_Phdr *phdr;

	info.ehdr = info.elf;
	info.shdrs = (const void *)info.ehdr + info.ehdr->e_shoff;
	info.phdrs = (const void *)info.ehdr + info.ehdr->e_phoff;
	info.secstrings = (const void *)info.ehdr +
		info.shdrs[info.ehdr->e_shstrndx].sh_offset;

	for_each_phdr(phdr, &info) {
		if (phdr->p_type != PT_LOAD)
			continue;

		memcpy((void *)phdr->p_vaddr, info.elf + phdr->p_offset, phdr->p_filesz);
	}

	asm volatile("b		%0" :: "r"(info.ehdr->e_entry));
}

static void find_and_exec_boot_elf(const struct fat_superblock *sb)
{
	unsigned long offs = fat_root_dir_offs(sb);
	int err;

	for (;;) {
		struct fat_dirent dirent;

		err = fat_read_dirent(sb, &dirent, &offs);
		if (err == -1) {
			putstr("no more dirents\n");
			break;
		}

		if (!wstrcmp(dirent.name, u"BOOT.ELF")) {
			if (!fat_dirent_is_dir(&dirent)) {
				fat_read_buf(sb, &dirent, load_buffer, LOAD_BUFFER_SIZE, 0);
				load_elf(load_buffer);
			}
		}
	}
}

#define TIMER_RELOAD_100MS ((50000000 / 1000) * 100)

static void wait_100ms(void)
{
	volatile unsigned long *timer_base = (volatile unsigned long *)0x80003000;
	unsigned long count;

	timer_base[1] = TIMER_RELOAD_100MS;
	timer_base[2] = 0x02;

	do {
		count = timer_base[0];
	} while (count != 0);
}

void boot_from_sd(void)
{
	unsigned long start = 0, size = 0;
	static unsigned char sector_buf[512];
	struct fat_superblock sb;

	wait_100ms();

	get_boot_partition_address(&start, &size);
	if (!start || !size) {
		putstr("no boot partition\n");
		goto out;
	}

	read_sector(start * 512, sector_buf);
	sb.partition_lba = start;
	fat_decode_boot_sect(sector_buf, &sb);
	find_and_exec_boot_elf(&sb);

out:
	putstr("ERROR: boot failed\n");
	for (;;)
		continue;
}
