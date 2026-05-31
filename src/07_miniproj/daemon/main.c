#include <errno.h>
#include <fcntl.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <sys/un.h>
#include <time.h>
#include <unistd.h>
#include <stdio.h>

#include <sys/timerfd.h>
#include <sys/epoll.h>
#include <syslog.h>

#include "oled/ssd1306.h"

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

#define SYSFS_FAN_FREQ   "/sys/class/fanctl/fanctl/frequency"
#define SYSFS_FAN_MODE   "/sys/class/fanctl/fanctl/mode"

// IPC
#define SOCKET_PATH "/tmp/fanctl.sock"

#define FREQ_MIN    1
#define FREQ_MAX    20

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

/* returns CPU temperature in milli-degrees Celsius. returns -1 in case of error */
static int read_cpu_temp(void)
{
    int temp = -1;
	int f = open("/sys/class/thermal/thermal_zone0/temp", O_RDONLY);
	if (f >= 0) {
		char val[50] = "";
		ssize_t r = read (f, val, sizeof(val));
		close (f);
		if (r > 0) {
			temp = atoi(val);
		}
	}
    return temp;
}

/* returns current fan frequency in Hz */
static int read_frequency(void)
{
    int freq = -1;
    char val[8] = "";   // freq [1;20]

    int f = open(SYSFS_FAN_FREQ, O_RDONLY);
    if (f >= 0) {
        ssize_t r = read(f, val, sizeof(val));
        close(f);
        if (r > 0)
            freq = atoi(val);
    }
    return freq;
}
static int write_fan_freq(int freq) {
    if (freq < FREQ_MIN || freq > FREQ_MAX) {
        syslog(LOG_ERR, "invalid frequency: %d", freq);
        return -1;
    }
    char val[8];
    snprintf(val, sizeof(val), "%d", freq);

    int f = open(SYSFS_FAN_FREQ, O_WRONLY);
    write(f, val, strlen(val));
    close(f);
    return 0;
}

/* returns current fan mode */
static const char* read_mode(void)
{
    static char val[16];

    int f = open(SYSFS_FAN_MODE, O_RDONLY);
    if (f < 0) return NULL;
    
    ssize_t r = read(f, val, sizeof(val)-1);    // keep a place for terminator
    close(f);
    if (r <= 0) return NULL;
    
    val[r] = '\0';
    val[strcspn(val, "\n")] = '\0'; // remove the \n in case of
    
    return val;
}
static int write_fan_mode(const char *mode) {

    int f = open(SYSFS_FAN_MODE, O_WRONLY);
    write(f, mode, strlen(mode));
    close(f);
    return 0;
}

static void initScreen(void) {
    ssd1306_init();

    ssd1306_set_position (0,0);
    ssd1306_puts("CSEL1a - SP.07");
    ssd1306_set_position (0,1);
    ssd1306_puts("  Demo - SW");
    ssd1306_set_position (0,2);
    ssd1306_puts("--------------");

    int temp = read_cpu_temp();
    int freq = read_frequency();
    const char* mode = read_mode();

    char buf[32];
    ssd1306_set_position (0,3);
    snprintf(buf, sizeof(buf), "Temp: %d.%02dC", temp / 1000, (temp / 10) % 100);
    ssd1306_puts(buf);
    ssd1306_set_position (0,4);
    snprintf(buf, sizeof(buf), "Freq: %2d Hz", freq);
    ssd1306_puts(buf);
    ssd1306_set_position (0,5);
    snprintf(buf, sizeof(buf), "Mode: %-6s", mode);
    ssd1306_puts(buf);
}

static const char* toggle_mode() 
{
    syslog(LOG_INFO, "toggle mode\n");
    // modify mode on sysfs
    const char* mode = read_mode();
    if (mode == NULL) {
        syslog(LOG_ERR, "Unable to read mode");
        return NULL;
    }
    const char* new_mode;
    new_mode = strcmp(mode, "auto") == 0 ? "manual" : "auto";
    write_fan_mode(new_mode);   // toggle mode
    return new_mode;
}

int main(int argc, char* argv[])
{
    openlog("fanctl_daemon", LOG_PID, LOG_USER);

    initScreen();

    struct itimerspec t;
    int timer_fd = timerfd_create(CLOCK_MONOTONIC, 0);

    t.it_value.tv_sec = 1;
    t.it_value.tv_nsec = 0;
    t.it_interval.tv_sec = 1;
    t.it_interval.tv_nsec = 0;
    timerfd_settime(timer_fd, 0, &t, NULL);

    // IPC
    unlink(SOCKET_PATH);    // remove if exists
    int sock_fd = socket(AF_UNIX, SOCK_STREAM, 0);
    struct sockaddr_un addr = {
        .sun_family = AF_UNIX,
    };
    strncpy(addr.sun_path, SOCKET_PATH, sizeof(addr.sun_path) - 1);
    bind(sock_fd, (struct sockaddr*)&addr, sizeof(addr));
    listen(sock_fd, 5);

    int epll_fd = epoll_create1(0);
    struct epoll_event ev[5];
    ev[0].events = EPOLLIN;
    ev[0].data.fd = timer_fd;
    epoll_ctl(epll_fd, EPOLL_CTL_ADD, timer_fd, &ev[0]);

    int led = open_led();

    // ecouter les fichiers pour savoir si il y a un appuis bouton
    int k1 = open_key(K1);
    ev[1].events = EPOLLET; // edge triggered
    ev[1].data.fd = k1;
    epoll_ctl(epll_fd, EPOLL_CTL_ADD, k1, &ev[1]);

    int k2 = open_key(K2);
    ev[2].events = EPOLLET; // edge triggered
    ev[2].data.fd = k2;
    epoll_ctl(epll_fd, EPOLL_CTL_ADD, k2, &ev[2]);

    int k3 = open_key(K3);
    ev[3].events = EPOLLET; // edge triggered
    ev[3].data.fd = k3;
    epoll_ctl(epll_fd, EPOLL_CTL_ADD, k3, &ev[3]);
    
    ev[4].events = EPOLLIN; // listen
    ev[4].data.fd = sock_fd;
    epoll_ctl(epll_fd, EPOLL_CTL_ADD, sock_fd, &ev[4]);

    // flush events after init
    struct epoll_event dummy_ev[5];
    epoll_wait(epll_fd, dummy_ev, 5, 0);  // timeout=0: non block, flush the queue

    syslog(LOG_INFO, "fanctl daemon started\n");

    uint64_t exp;
    int nb_events = 0;
    while (1) {
        nb_events = epoll_wait(epll_fd, ev, 5, -1);
        for (int i = 0; i < nb_events; i++) {
            if (ev[i].data.fd == timer_fd) {
                // read timer fd to clear event               
                read(timer_fd, &exp, sizeof(uint64_t));
                int temp = read_cpu_temp();
                int freq = read_frequency();
                const char* mode = read_mode();
                
                char buf[32];
                ssd1306_set_position (0,3);
                snprintf(buf, sizeof(buf), "Temp: %d.%02dC", temp / 1000, (temp / 10) % 100);
                ssd1306_puts(buf);
                ssd1306_set_position (0,4);
                snprintf(buf, sizeof(buf), "Freq: %2d Hz", freq);
                ssd1306_puts(buf);
                ssd1306_set_position (0,5);
                snprintf(buf, sizeof(buf), "Mode: %-6s", mode);
                ssd1306_puts(buf);
            }
            else if (ev[i].data.fd == k1) {           

                // TODO: blink la led differemment si erreur? ou ne pas la blink? (probablement pas ne pas la blink)
                syslog(LOG_INFO, "S1: increase frequency\n");
                blink_power_led(led);

                // check the mode
                const char* mode = read_mode();
                if (strcmp(mode, "auto") == 0) {
                    syslog(LOG_WARNING, "mode is manual, button ignored");
                    continue;
                }

                // modify frequency on sysfs: read to know the value and increase
                int freq = read_frequency();
                if (freq == -1) {
                    syslog(LOG_ERR, "Unable to change frequency: error during reading frequency");
                    continue;
                }
                if (freq >= FREQ_MAX) {
                    syslog(LOG_INFO, "frequency already at max (%d Hz)", FREQ_MAX);
                    continue;
                }
                int new_freq = freq+1;
                syslog(LOG_INFO, "S2: frequency increased from %d Hz to %d Hz\n", freq, new_freq );
                write_fan_freq(new_freq);

                // update screen
                char buf[32];
                ssd1306_set_position (0,4);
                snprintf(buf, sizeof(buf), "Freq: %2d Hz", new_freq);
                ssd1306_puts(buf);
            }
            else if (ev[i].data.fd == k2) {
                syslog(LOG_INFO, "S2: decrease frequency\n");
                blink_power_led(led);

                // check the mode
                const char* mode = read_mode();
                if (strcmp(mode, "auto") == 0) {
                    syslog(LOG_WARNING, "mode is manual, button ignored");
                    continue;
                }

                // modify frequency on sysfs: read to know the value and decrease
                int freq = read_frequency();
                if (freq == -1) {
                    syslog(LOG_ERR, "Unable to change frequency: error during reading frequency");
                    continue;
                }
                if (freq <= FREQ_MIN) {
                    syslog(LOG_INFO, "frequency already at min (%d Hz)", FREQ_MIN);
                    continue;
                }
                int new_freq = freq-1;
                syslog(LOG_INFO, "S2: frequency decreased from %d Hz to %d Hz\n", freq, new_freq );
                write_fan_freq(new_freq);

                // update screen
                char buf[32];
                ssd1306_set_position (0,4);
                snprintf(buf, sizeof(buf), "Freq: %2d Hz", new_freq);
                ssd1306_puts(buf);

            }
            else if (ev[i].data.fd == k3) {
                const char* new_mode = toggle_mode();
                if (new_mode == NULL) {
                    syslog(LOG_ERR, "Unable to toggle mode");
                    continue;
                }
                
                // update screen
                char buf[32];
                ssd1306_set_position (0,5);
                snprintf(buf, sizeof(buf), "Mode: %-6s", new_mode);
                ssd1306_puts(buf);
                // update freq in case of
                int freq = read_frequency();
                ssd1306_set_position (0,4);
                snprintf(buf, sizeof(buf), "Freq: %2d Hz", freq);
                ssd1306_puts(buf);

            }
            else if (ev[i].data.fd == sock_fd) {
                int client_fd = accept(sock_fd, NULL, NULL);
                if (client_fd < 0) continue;
                
                char cmd[32] = {0};
                char resp[64] = {0};
                
                read(client_fd, cmd, sizeof(cmd) - 1);
                cmd[strcspn(cmd, "\n")] = '\0';

                syslog(LOG_INFO, "IPC command: %s", cmd);

                if (strcmp(cmd, "status") == 0) {
                    int temp = read_cpu_temp();
                    int freq = read_frequency();
                    const char* mode = read_mode();
                    snprintf(resp, sizeof(resp), "temp:%d.%02d mode:%s freq:%d",
                        temp / 1000, (temp / 10) % 100, mode, freq);

                } else if (strcmp(cmd, "mode toggle") == 0) {
                    const char* new_mode = toggle_mode();
                    if (new_mode == NULL) {
                        syslog(LOG_ERR, "Unable to toggle mode");
                        snprintf(resp, sizeof(resp), "error: mode toggle impossible");
                    } else {
                    snprintf(resp, sizeof(resp), "mode %s", new_mode);
                    }

                } else if (strncmp(cmd, "freq ", 5) == 0) {
                    int freq = atoi(cmd + 5);
                    if (write_fan_freq(freq) == 0)
                        snprintf(resp, sizeof(resp), "freq %d Hz", freq);
                    else
                        snprintf(resp, sizeof(resp), "error: invalid frequency");

                } else {
                    snprintf(resp, sizeof(resp), "error: unknown command");
                }

                // send response
                write(client_fd, resp, strlen(resp));
                close(client_fd);
            }
        }
    }
    closelog();
    return 0;
}