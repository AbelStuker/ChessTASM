//
// Created by Abel Stuker on 23/12/2023.
//
#include <stdio.h>
#include <string.h>
#include <ascii_bitmap.h>

int main() {
    FILE *outputFile;
    outputFile = fopen("font.bin", "wb");
    if (outputFile == NULL) {
        printf("Error opening file for writing.\n");
        return 1;
    }

    printf("Bytes per font character: %i\n", FONT_BYTES);

    int val = 0;
    while (val < 128) {
        char str[3+4+1]; // number (max 3 bits)
        sprintf(str, "%i", val);
        strcat(str, ".bin");
        FILE *charFile;
        if((charFile = fopen(str, "r"))) {
            printf("Adding ASCII character %c to font.\n", val);
            char toCopy;
            while ((toCopy = fgetc(charFile)) != EOF) {
                fputc(toCopy, outputFile);
            }
            printf("\n");
            fclose(charFile);
        } else {
            int empty_bytes = FONT_BYTES;
            while (empty_bytes-- > 0) {
                fputc(0, outputFile);
            }
        }
        val++;
    }

    fclose(outputFile);
    printf("ASCII bitmap made");
    return 0;
}



