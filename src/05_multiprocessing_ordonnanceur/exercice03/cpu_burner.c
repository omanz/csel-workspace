#include <stdio.h>
#include <unistd.h>
#include <signal.h>

static volatile int running = 1;

void handle_signal(int sig)
{
    (void)sig;
    running = 0;
}

int main(void)
{
    // capture des signaux pour un arret sans crash
    signal(SIGINT, handle_signal);
    signal(SIGTERM, handle_signal);

    printf("[INFO] CPU burner started (PID=%d)\n", getpid());

    // variable volatile pour éviter optimisation du compilateur
    volatile unsigned long long i = 0;

    while (running)
    {
        i++;
    }

    printf("[INFO] stopped. counter=%llu\n", i);

    return 0;
}