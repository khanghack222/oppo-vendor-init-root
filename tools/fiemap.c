/*
 * fiemap - print the physical layout of a file (ext4 extents).
 *
 *   fiemap <file>
 *
 * Output, one extent per line:
 *
 *   <logical_off> <physical_off> <length> <flags>
 *
 * Physical offsets are in bytes from the start of the block device, so the
 * caller can rewrite the file's content with dd without mounting the
 * filesystem read-write (used for the dm-verity-free /system partition).
 */
#define _GNU_SOURCE
#include <fcntl.h>
#include <linux/fiemap.h>
#include <linux/fs.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/ioctl.h>
#include <unistd.h>

#define MAXEXT 256

int main(int argc, char **argv)
{
    struct fiemap *fm;
    int fd, i;

    if (argc < 2) {
        fprintf(stderr, "usage: %s <file>\n", argv[0]);
        return 1;
    }

    fd = open(argv[1], O_RDONLY);
    if (fd < 0) {
        perror("open");
        return 1;
    }

    fm = calloc(1, sizeof(*fm) + MAXEXT * sizeof(struct fiemap_extent));
    fm->fm_start = 0;
    fm->fm_length = ~0ULL;
    fm->fm_flags = FIEMAP_FLAG_SYNC;
    fm->fm_extent_count = MAXEXT;

    if (ioctl(fd, FS_IOC_FIEMAP, fm) < 0) {
        perror("ioctl FIEMAP");
        return 1;
    }

    for (i = 0; i < (int)fm->fm_mapped_extents; i++) {
        struct fiemap_extent *e = &fm->fm_extents[i];
        printf("%llu %llu %llu 0x%x\n",
               (unsigned long long)e->fe_logical,
               (unsigned long long)e->fe_physical,
               (unsigned long long)e->fe_length,
               e->fe_flags);
    }
    printf("mapped=%u\n", fm->fm_mapped_extents);
    close(fd);
    return 0;
}
