EXE=cpu_burner
SRCS=cpu_burner.c

TOOLCHAIN_PATH=/buildroot/output/host/usr/bin
CROSS_PREFIX=$(TOOLCHAIN_PATH)/aarch64-linux-

CC=$(CROSS_PREFIX)gcc

CFLAGS=-Wall -Wextra -g -O0 -std=gnu11

all: $(EXE)

$(EXE): $(SRCS)
	$(CC) $(CFLAGS) $^ -o $@

clean:
	rm -f $(EXE)

.PHONY: all clean