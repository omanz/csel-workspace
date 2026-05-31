#include <fcntl.h>
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <unistd.h>

#define FIFO_CMD      "/tmp/fanctl_cmd.fifo"
#define FIFO_RESPONSE "/tmp/fanctl_resp.fifo"

int main(int argc, char* argv[])
{
    if (argc < 2) {
        printf("Usage: fanctl_cli status\n");
        printf("       fanctl_cli mode toggle\n");
        printf("       fanctl_cli freq <1-20>\n");
        return 1;
    }

    // open response file
    int resp_fd = open(FIFO_RESPONSE, O_RDONLY | O_NONBLOCK);
    if (resp_fd < 0) {
        perror("failed to open response FIFO");
        return 1;
    }

    // flush response file
    char flush_buf[256];
    ssize_t r;
    do {
        r = read(resp_fd, flush_buf, sizeof(flush_buf));
    } while (r > 0);

    // open command file
    int cmd_fd = open(FIFO_CMD, O_WRONLY);
    if (cmd_fd < 0) {
        perror("failed to open command FIFO");
        return 1;
    }

    char cmd[32] = {0};
    if (argc == 3)
        snprintf(cmd, sizeof(cmd), "%s %s", argv[1], argv[2]);
    else
        snprintf(cmd, sizeof(cmd), "%s", argv[1]);

    write(cmd_fd, cmd, strlen(cmd));
    close(cmd_fd);

    // attendre et lire la réponse
    usleep(100000);  // 100ms
    char resp[64] = {0};
    read(resp_fd, resp, sizeof(resp) - 1);
    printf("%s\n", resp);
    close(resp_fd);

    return 0;
}