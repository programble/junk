#include <stdlib.h>
#include <stdio.h>
#include <errno.h>

int main(int argc, char *argv[])
{
    if (argc != 3) {
        printf("usage: file2c file array\n");
        return EXIT_SUCCESS;
    }
    
    FILE *file = fopen(argv[1], "r");
    if (!file) {
        perror(argv[1]);
        return EXIT_FAILURE;
    }
    
    printf("static const unsigned char %s[] = {\n    ", argv[2]);
    int column = 0;
    unsigned char byte;
    while (fread(&byte, 1, 1, file) == 1) {
        printf("0x%.2x, ", byte);
        if (++column == 16) {
            printf("\n    ");
            column = 0;
        }
    }
    fclose(file);
    printf("\n};\n");
    return EXIT_SUCCESS;
}
