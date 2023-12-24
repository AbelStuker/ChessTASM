CC=gcc
CFLAGS=-I.
DEPS =
OBJ = stringtobitmap.c

%.o: %.c $(DEPS)
	$(CC) -c -o $@ $< $(CFLAGS)

stb: $(OBJ)
	$(CC) -o $@ $^ $(CFLAGS)
