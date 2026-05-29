#include <errno.h>
#include <fcntl.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <time.h>
#include <unistd.h>
#include <stdio.h>

#include <sys/timerfd.h>
#include <sys/epoll.h>
#include <syslog.h>

/*
 * status led - gpioa.10 --> gpio10
 * power led  - gpiol.10 --> gpio362
 */
#define GPIO_EXPORT   "/sys/class/gpio/export"
#define GPIO_UNEXPORT "/sys/class/gpio/unexport"
#define GPIO_LED      "/sys/class/gpio/gpio362"
#define LED           "362"
#define K1            "0"
#define K2            "2"
#define K3            "3"

static int open_led()
{
    // unexport pin out of sysfs (reinitialization)
    int f = open(GPIO_UNEXPORT, O_WRONLY);
    write(f, LED, strlen(LED));
    close(f);

    // export pin to sysfs
    f = open(GPIO_EXPORT, O_WRONLY);
    write(f, LED, strlen(LED));
    close(f);

    // config pin
    f = open(GPIO_LED "/direction", O_WRONLY);
    write(f, "out", 3);
    close(f);

    // open gpio value attribute
    f = open(GPIO_LED "/value", O_RDWR);
    return f;
}

static void blink_power_led(int led_fd)
{
    pwrite(led_fd, "1", 1, 0);
    usleep(100000);   // 100ms
    pwrite(led_fd, "0", 1, 0);
}

int open_key(const char* k)
{
    // unexport pin out of sysfs (reinitialization)
    int f = open(GPIO_UNEXPORT, O_WRONLY);
    write(f, k, strlen(k));
    close(f);

    // export pin to sysfs
    f = open(GPIO_EXPORT, O_WRONLY);
    write(f, k, strlen(k));
    close(f);

    // config pin
    // set it as an input
    char path[64];
    sprintf(path, "/sys/class/gpio/gpio%s/direction", k); // set pin as input
    f = open(path, O_WRONLY);
    write(f, "in", 2);
    close(f);

    // set interrupt on rising edge
    sprintf(path, "/sys/class/gpio/gpio%s/edge", k); // set interrupt on rising edge
    f = open(path, O_WRONLY);
    write(f, "rising", 6);
    close(f);

    // open gpio value attribute
    sprintf(path, "/sys/class/gpio/gpio%s/value", k);
    return open(path, O_RDONLY);
}

int main(int argc, char* argv[])
{
    openlog("fanctl_daemon", LOG_PID, LOG_USER);

    int epll_fd = epoll_create1(0);
    struct epoll_event ev[3];

    char led_state = '1';
    int led = open_led();

    // ecouter les fichiers pour savoir si il y a un appuis bouton
    int k1 = open_key(K1);
    ev[0].events = EPOLLET; // edge triggered
    ev[0].data.fd = k1;
    epoll_ctl(epll_fd, EPOLL_CTL_ADD, k1, &ev[0]);

    int k2 = open_key(K2);
    ev[1].events = EPOLLET; // edge triggered
    ev[1].data.fd = k2;
    epoll_ctl(epll_fd, EPOLL_CTL_ADD, k2, &ev[1]);

    int k3 = open_key(K3);
    ev[2].events = EPOLLET; // edge triggered
    ev[2].data.fd = k3;
    epoll_ctl(epll_fd, EPOLL_CTL_ADD, k3, &ev[2]);
    
    syslog(LOG_INFO, "fanctl daemon started\n");

    uint64_t exp;
    int nb_events = 0;
    while (1) {
        nb_events = epoll_wait(epll_fd, ev, 3, -1);
        for (int i = 0; i < nb_events; i++) {
            if (ev[i].data.fd == k1) {           
                syslog(LOG_INFO, "S1: increase frequency\n");
                blink_power_led(led);
                // modify frequency on sysfs
            }
            else if (ev[i].data.fd == k2) {
                syslog(LOG_INFO, "S2: decrease frequency\n");
                blink_power_led(led);
                // modify frequency on sysfs
            }
            else if (ev[i].data.fd == k3) {
                syslog(LOG_INFO, "toggle mode\n");
                // modify mode on sysfs
            }
        }
    }
    closelog();
    return 0;
}