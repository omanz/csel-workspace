/**
 * Copyright 2018 University of Applied Sciences Western Switzerland / Fribourg
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 *
 * Project: HEIA-FR / HES-SO MSE - MA-CSEL1 Laboratory
 *
 * Abstract: System programming -  file system
 *
 * Purpose: NanoPi silly status led control system
 *
 * Autĥor:  Daniel Gachet
 * Date:    07.11.2018
 */
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
#define GPIO_LED      "/sys/class/gpio/gpio10"
#define LED           "10"
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
    openlog("silly_led_control", LOG_PID, LOG_USER);
    // to see the logs use :
    // tail -f /var/log/messages

    // duty cycle at 50%
    long default_period = 1000;  // ms
    if (argc >= 2) default_period = atoi(argv[1]);
    long period = default_period;
    period *= 1000000;  // in ns

    struct itimerspec t;
    int timer_fd = timerfd_create(CLOCK_MONOTONIC, 0);

    t.it_value.tv_sec = period / 1000000000;
    t.it_value.tv_nsec = period % 1000000000;
    t.it_interval.tv_sec = t.it_value.tv_sec;
    t.it_interval.tv_nsec = t.it_value.tv_nsec;
    timerfd_settime(timer_fd, 0, &t, NULL);

    int epll_fd = epoll_create1(0);
    struct epoll_event ev[5];
    ev[0].events = EPOLLIN;
    ev[0].data.fd = timer_fd;
    epoll_ctl(epll_fd, EPOLL_CTL_ADD, timer_fd, &ev[0]);

    char led_state = '1';
    int led = open_led();

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
    
    uint64_t exp;
    int nb_events = 0;
    while (1) {
        nb_events = epoll_wait(epll_fd, ev, 5, -1);
        for (int i = 0; i < nb_events; i++) {
            if (ev[i].data.fd == timer_fd) {
                // read timer fd to clear event               
                read(timer_fd, &exp, sizeof(uint64_t));

                // toggle led state
                if (led_state == '1') {
                    pwrite(led, "0", sizeof("0"), 0);
                    led_state = '0';
                }
                else {
                    pwrite(led, "1", sizeof("1"), 0);
                    led_state = '1';
                }                
            }
            else if (ev[i].data.fd == k1) {           
                period -= 10000000;
                if (period <= 0) period = 1000000;
                t.it_value.tv_sec = period / 1000000000;
                t.it_value.tv_nsec = period % 1000000000;
                t.it_interval.tv_sec = t.it_value.tv_sec;
                t.it_interval.tv_nsec = t.it_value.tv_nsec;
                timerfd_settime(timer_fd, 0, &t, NULL);
                syslog(LOG_INFO, "period = %ld ms\n", period / 1000000);
            }
            else if (ev[i].data.fd == k2) {
                period = default_period * 1000000;
                t.it_value.tv_sec = period / 1000000000;
                t.it_value.tv_nsec = period % 1000000000;
                t.it_interval.tv_sec = t.it_value.tv_sec;
                t.it_interval.tv_nsec = t.it_value.tv_nsec;
                timerfd_settime(timer_fd, 0, &t, NULL);
                syslog(LOG_INFO,  "period = %ld ms\n", period / 1000000);
            }
            else if (ev[i].data.fd == k3) {
                period += 10000000;
                t.it_value.tv_sec = period / 1000000000;
                t.it_value.tv_nsec = period % 1000000000;
                t.it_interval.tv_sec = t.it_value.tv_sec;
                t.it_interval.tv_nsec = t.it_value.tv_nsec;
                timerfd_settime(timer_fd, 0, &t, NULL);
                syslog(LOG_INFO, "period = %ld ms\n", period / 1000000);
            }
        }
    }
    closelog();
    return 0;
}