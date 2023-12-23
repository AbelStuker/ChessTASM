CC=gcc
CFLAGS=-I.
DEPS = ascii_bitmap.h
OBJ = generate_ascii_bitmap.c

%.o: %.c $(DEPS)
	$(CC) -c -o $@ $< $(CFLAGS)

gen_font: $(OBJ)
	$(CC) -o $@ $^ $(CFLAGS)
