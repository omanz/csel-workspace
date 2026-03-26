#include <fcntl.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/errno.h>
#include <sys/mman.h>
#include <unistd.h>

int main()
{
    /* Ouverture du fichier correspondant au pilote */
    int fd = open("/dev/mem", O_RDWR);
    if (fd < 0) {
        printf("Could not open /dev/mem: error=%i\n", fd);
        return -1;
    }
    /* placer dans la mem virt du processeur les registres du periph */
    size_t psz     = getpagesize();
    off_t dev_addr = 0x01c14200;
    off_t ofs      = dev_addr % psz;    // difference entre le debut de la page et la plage mem
    off_t offset   = dev_addr - ofs;    // adresse de debut de page

    volatile uint32_t* regs =
    mmap (NULL,         // adr de depart en memoire
        psz,            // taille de zone a placer en mem virtuelle (multiple de taille de page)
        PROT_READ,      // droit acces a la memoire
        MAP_PRIVATE,    // visibilité de la page
        fd,
        offset);        // offset des registres en memoire phyique

    if (regs == MAP_FAILED) {
        printf("mmap failed, error: %i:%s \n", errno, strerror(errno));
        return -1;
    }

    // info tout les 4, ce sera le pas
    uint32_t chipid[4] = {
        [0] = *(regs + (ofs + 0x00) / sizeof(uint32_t)),
        [1] = *(regs + (ofs + 0x04) / sizeof(uint32_t)),
        [2] = *(regs + (ofs + 0x08) / sizeof(uint32_t)),
        [3] = *(regs + (ofs + 0x0c) / sizeof(uint32_t)),
    };

    printf("NanoPi NEO Plus2 chipid=%08x'%08x'%08x'%08x\n",
           chipid[0],
           chipid[1],
           chipid[2],
           chipid[3]);

    munmap((void*)regs, psz);
    close(fd);

    return 0;
}
