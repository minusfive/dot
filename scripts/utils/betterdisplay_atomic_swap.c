#include <errno.h>
#include <stdio.h>
#include <stdlib.h>

#include <sys/attr.h>

int
main(int argc, char **argv)
{
    if (argc != 3) {
        fprintf(stderr, "usage: betterdisplay_atomic_swap SOURCE TARGET\n");
        return 64;
    }

    if (renamex_np(argv[1], argv[2], RENAME_SWAP) != 0) {
        perror("renamex_np");
        return errno == 0 ? 1 : errno;
    }

    return EXIT_SUCCESS;
}
