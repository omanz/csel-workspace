#include <fcntl.h>
#include <stdio.h>
#include <string.h>
#include <sys/socket.h>
#include <sys/un.h>
#include <unistd.h>

#define SOCKET_PATH "/tmp/fanctl.sock"

int main(int argc, char* argv[])
{
    if (argc < 2) {
        printf("Usage: fanctl_cli status\n");
        printf("       fanctl_cli mode toggle\n");
        printf("       fanctl_cli freq <1-20>\n");
        return 1;
    }

    int sock = socket(AF_UNIX, SOCK_STREAM, 0);
    if (sock < 0) {
        perror("socket failed");
        return 1;
    }
    struct sockaddr_un addr = {
        .sun_family = AF_UNIX,
    };
    strncpy(addr.sun_path, SOCKET_PATH, sizeof(addr.sun_path) - 1);

    if (connect(sock, (struct sockaddr*)&addr, sizeof(addr)) < 0) {
        perror("failed to connect");
        close(sock);
        return 1;
    }

    char cmd[32] = {0};
    if (argc == 3)
        snprintf(cmd, sizeof(cmd), "%s %s", argv[1], argv[2]);
    else
        snprintf(cmd, sizeof(cmd), "%s", argv[1]);

    write(sock, cmd, strlen(cmd));

    char resp[64] = {0};
    read(sock, resp, sizeof(resp) - 1);
    printf("%s\n", resp);
    close(sock);

    return 0;
}