EXE=app
SRCS=app.c

TOOLCHAIN_PATH=/buildroot/output/host/usr/bin
CROSS_PREFIX=$(TOOLCHAIN_PATH)/aarch64-linux-

CC=$(CROSS_PREFIX)gcc

CFLAGS=-Wall -Wextra -g -O0 -std=gnu11 -pthread

all: $(EXE)

$(EXE): $(SRCS)
	$(CC) $(CFLAGS) $^ -o $@

clean:
	rm -f $(EXE)

run: all
	./$(EXE)

.PHONY: all clean run