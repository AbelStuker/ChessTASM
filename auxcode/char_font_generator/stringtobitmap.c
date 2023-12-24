#include <stdio.h>
#include <string.h>

int main() {
    char foldername[11];
    printf("Enter folder where all character font binaries should be stored: ");
    scanf("%s", foldername);
    // Unsafe, we know, but don't care for now :)

    while (1)
    {
        char input[1000]; // Maximum length of the input string
        char filename[11];
        char relative_file_path[3+10+1+10+1] = "../";
        // Again, we don't care about safety here
        printf("Enter a string of binary (0s and 1s): ");
        scanf("%s", input);
        printf("Enter name of file: ");
        scanf("%s", filename);

        strcat(relative_file_path, foldername);
        strcat(relative_file_path, "/");
        strcat(relative_file_path, strcat(filename, ".bin"));

        FILE *outputFile;
        outputFile = fopen(relative_file_path, "wb"); // Open the file for writing in binary mode

        if (outputFile == NULL) {
            printf("Error opening file for writing.\n");
            return 1;
        }

        int length = strlen(input);
        char byte = 0;
        int bitCount = 0;

        for (int i = 0; i < length; i++) {
            if (input[i] == '0' || input[i] == '1') {
                byte = (byte << 1) | (input[i] - '0');
                bitCount++;

                if (bitCount == 8) {
                    fwrite(&byte, sizeof(char), 1, outputFile); // Write a byte to the binary file
                    byte = 0;
                    bitCount = 0;
                }
            } else {
                printf("Invalid character in input: %c\n", input[i]);
                fclose(outputFile);
                return 1;
            }
        }

        if (bitCount > 0) {
            // Pad the last byte with zeros if needed
            byte = byte << (8 - bitCount);
            fwrite(&byte, sizeof(char), 1, outputFile);
        }

        fclose(outputFile);
        printf("Binary data written to '%s'.\n", filename);
    }
    return 0;
}



