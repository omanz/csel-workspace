#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <string.h>
#include <signal.h>
#include <sys/socket.h>
#include <sys/types.h>
#include <sched.h>
#include <errno.h>

#define BUF_SIZE 128

static void catch_signal(int signal)
{
    const char *name;

    switch (signal)
    {
        case SIGHUP:  name = "SIGHUP"; break;
        case SIGINT:  name = "SIGINT"; break;
        case SIGQUIT: name = "SIGQUIT"; break;
        case SIGABRT: name = "SIGABRT"; break;
        case SIGTERM: name = "SIGTERM"; break;
        default:      name = "UNKNOWN"; break;
    }

    printf("[SIGNAL IGNORED] reçu %s (%d)\n", name, signal);
}

static void install_signals(void)
{
    struct sigaction act = {
        .sa_handler = catch_signal,
    };
    //memset(&sa, 0, sizeof(sa));
    //sa.sa_handler = signal_handler;

    sigaction(SIGHUP, &act, NULL);  // 1 - hangup
    sigaction(SIGINT, &act, NULL);  // 2 - terminal interrupt
    sigaction(SIGQUIT, &act, NULL); // 3 - terminal quit
    sigaction(SIGABRT, &act, NULL); // 6 - abort
    sigaction(SIGTERM, &act, NULL); // 15 - termination
}

static void set_cpu(int cpu)
{
    cpu_set_t set;
    CPU_ZERO(&set);
    CPU_SET(cpu, &set);

    int ret = sched_setaffinity(0, sizeof(set), &set);
    if (ret == -1)
    {
        perror("sched_setaffinity");
        exit(EXIT_FAILURE);
    }
}

int main(void)
{
    int fd[2]; // socketpair
    pid_t pid;
    char buf[BUF_SIZE];

    install_signals();

    int err = socketpair(AF_UNIX, SOCK_STREAM, 0, fd);
    if (err == -1)
    {
        perror("socketpair");
        exit(EXIT_FAILURE);
    }

    pid = fork();

    if (pid < 0)
    {
        perror("fork");
        exit(EXIT_FAILURE);
    }

    // =========================
    // Enfant (core 1)
    // =========================
    if (pid == 0)   // enfant a le pid 0
    {
        set_cpu(1);
        // fd[1] pour enfant, fermer l'autre
        close(fd[0]);

        
        // l'enfant lis l'entrée clavier et envoie le message au parent
        char input[128];

        while (1)
        {
            if (fgets(input, sizeof(input), stdin) == NULL)
            {
                // si signal intercepté par enfant, clean buffer
                if (errno == EINTR)
                {
                    clearerr(stdin);
                    continue;
                }
                break;
            }

            input[strcspn(input, "\n")] = 0;
            //printf("[CHILD] write: %s\n", input);
            write(fd[1], input, strlen(input) + 1);

            if (strcmp(input, "exit") == 0)
                break;
        }

        close(fd[1]);
        exit(0);
    }

    // =========================
    // Parent (core 0)
    // =========================
    set_cpu(0);

    // fd[0] pour parent, fermer l'autre
    close(fd[1]);

    while (1)
    {
        memset(buf, 0, BUF_SIZE);

        int n = read(fd[0], buf, BUF_SIZE);
        if (n < 0)
        {
            if (errno == EINTR)
            {
                continue; // signal reçu
            }

            perror("read");
            break;
        }

        if (n == 0)
        {
            printf("[PARENT] socket fermé\n");
            break;
        }
        printf("[PARENT] reçu: %s\n", buf);

        if (strcmp(buf, "exit") == 0)
        {
            printf("[PARENT] exit reçu\n");
            break;
        }
    }

    close(fd[0]);

    printf("[PARENT] terminé\n");
    return 0;
}