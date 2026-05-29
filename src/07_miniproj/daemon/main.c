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

#define SYSFS_FAN_FREQ   "/sys/class/fanctl/fanctl/frequency"
#define SYSFS_FAN_MODE   "/sys/class/fanctl/fanctl/mode"

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

/* returns current fan mode: 0=auto, 1=manual, -1=error */
// TODO: read en string pour ne pas s'embrouiller
static int read_mode(void)
{
    char val[16] = "";

    int f = open(SYSFS_FAN_MODE, O_RDONLY);
    if (f >= 0) {
        read(f, val, sizeof(val));
        close(f);
    } else {
        return -1;
    }

    if (strncmp(val, "auto", 4) == 0)   return 0;
    if (strncmp(val, "manual", 6) == 0) return 1;
    return -1;
}
static int write_fan_mode(const char *mode) {

    int f = open(SYSFS_FAN_MODE, O_WRONLY);
    write(f, mode, strlen(mode));
    close(f);
    return 0;
}

int main(int argc, char* argv[])
{
    openlog("fanctl_daemon", LOG_PID, LOG_USER);

    int epll_fd = epoll_create1(0);
    struct epoll_event ev[3];

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

    int nb_events = 0;
    while (1) {
        nb_events = epoll_wait(epll_fd, ev, 3, -1);
        for (int i = 0; i < nb_events; i++) {
            if (ev[i].data.fd == k1) {           

                // TODO: verifier le mode avant et afficher une erreur.
                // TODO: blink la led differemment si erreur? ou ne pas la blink? (probablement pas ne pas la blink)
                syslog(LOG_INFO, "S1: increase frequency\n");
                blink_power_led(led);
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
                syslog(LOG_INFO, "S2: frequency increased from %d Hz to %d Hz\n", freq, freq+1 );
                write_fan_freq(freq + 1);
            }
            else if (ev[i].data.fd == k2) {
                syslog(LOG_INFO, "S2: decrease frequency\n");
                blink_power_led(led);
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
                syslog(LOG_INFO, "S2: frequency decreased from %d Hz to %d Hz\n", freq, freq-1 );
                write_fan_freq(freq - 1);
            }
            else if (ev[i].data.fd == k3) {
                syslog(LOG_INFO, "toggle mode\n");
                // modify mode on sysfs
                int temp = read_cpu_temp();
                syslog(LOG_INFO, "CPU temp: %d.%02d°C", temp / 1000, (temp / 10) % 100);
                int mode_int = read_mode();
                syslog(LOG_INFO, "Fan mode: %d", mode_int);
                write_fan_mode(mode_int == 0 ? "manual" : "auto");   // toggle mode
                mode_int = read_mode();
                syslog(LOG_INFO, "Fan mode: %d", mode_int);
                
                syslog(LOG_INFO, "Fan freq: %d Hz", read_frequency());
            }
        }
    }
    closelog();
    return 0;
}