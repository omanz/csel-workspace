#include <stdio.h>
#include <fcntl.h>
#include <unistd.h>
#include <string.h>
#include <sys/ioctl.h>
#include "skeleton.h"

int main() {
    int fd = open("/dev/mymodule", O_RDWR);

    // reset
    ioctl(fd, SKELETON_IO_RESET);

    // write/read val
    int val = 42;
    ioctl(fd, SKELETON_IO_WR_VAL, &val);
    ioctl(fd, SKELETON_IO_RD_VAL, &val);
    printf("val=%d\n", val);

    // write/read config
    struct skeleton_config config = {1, 100, "test", "description"};
    ioctl(fd, SKELETON_IO_WR_REF, &config);
    memset(&config, 0, sizeof(config));
    ioctl(fd, SKELETON_IO_RD_REF, &config);
    printf("config: id=%d ref=%ld name=%s descr=%s\n",
           config.id, config.ref, config.name, config.descr);

    close(fd);
    return 0;
}