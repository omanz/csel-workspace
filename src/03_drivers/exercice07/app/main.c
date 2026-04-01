#include <stdio.h>  
#include <fcntl.h>
#include <unistd.h>
#include <sys/select.h>

int main()
{
    int count = 0;
    int fd = open("/dev/mymodule", O_RDONLY);

    while (1) {
        fd_set rfds;
        FD_ZERO(&rfds);
        FD_SET(fd, &rfds);

        select(fd + 1, &rfds, NULL, NULL, NULL);  // bloque jusqu'à interruption
        read(fd, NULL, 0);   // consomme l'événement dans le driver
        count++;             // l'app compte
        printf("nb interruptions: %d\n", count);
    }
}