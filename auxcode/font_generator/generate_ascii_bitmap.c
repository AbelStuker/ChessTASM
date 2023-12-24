//
// Created by Abel Stuker on 23/12/2023.
//
#include <stdio.h>
#include <string.h>
#include <ascii_bitmap.h>

int main() {

    char filename[8];
    // Unsafe, we know, but don't care for now :)
    printf("Enter name of the folder that contains the fonts: ");
    scanf("%s", filename);

    char outputname[3+11] = "../";
    strcat(outputname, filename);

    FILE *outputFile;
    outputFile = fopen(strcat(outputname, ".bin"), "wb");
    if (outputFile == NULL) {
        printf("Error opening file for writing.\n");
        return 1;
    }

    printf("Bytes per font character: %i\n", FONT_BYTES);

    int val = 0;
    while (val < 128) {
        char str[3+10+13+4+1]; // folder name (max 10 bytes) + '/' (1 byte) + number (max 3 bytes) + .bin extension (4 bytes) + null termination (1 byte)
        sprintf(str, "../%s/%i.bin", filename, val);
        FILE *charFile;
        if((charFile = fopen(str, "r"))) {
            char toCopy;
            while ((toCopy = fgetc(charFile)) != EOF) {
                fputc(toCopy, outputFile);
            }
            printf("%s : ",str);
            printf("Added ASCII character %c to font.\n", val);
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
    printf("ASCII bitmap made: %s.bin\n", filename);
    return 0;
}



