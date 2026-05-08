#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#define BLOCK_SIZE (1024 * 1024) // 1 Mebibyte
#define NB_BLOCKS 50

int main(void)
{
    void *blocks[NB_BLOCKS];

    printf("[INFO] Allocating %d blocs\n", NB_BLOCKS);

    for (int i = 0; i < NB_BLOCKS; i++)
    {
        // allocation
        blocks[i] = malloc(BLOCK_SIZE);

        // check
        if (blocks[i] == NULL)
        {
            perror("malloc");
            printf("[ERROR] Failed to allocate block  %d\n", i);
            exit(EXIT_FAILURE);
        }

        // remplissage avec des 0 pour eviter que le systeme optimise
        memset(blocks[i], 0, BLOCK_SIZE);

        printf("[INFO] Block %d allocated (%d MiB)\n", i + 1, i + 1);


        sleep(1);
    }

    printf("[INFO] All allocations completed successfully\n");

    // laisser le programme tourner indefiniment
    while (1)
    {
        sleep(1);
    }

    return 0;
}