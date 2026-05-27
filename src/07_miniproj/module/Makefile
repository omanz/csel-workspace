MODPATH  := /rootfs

target=nano

TOOLCHAIN_PATH=/buildroot/output/host/usr/bin/
TOOLCHAIN=$(TOOLCHAIN_PATH)aarch64-linux-

CVER     := aarch64-linux-
KVER     := 5.15.148
CPU      := arm64
KDIR     := /buildroot/output/build/linux-$(KVER)/
PWD      := $(shell pwd)

export PATH := $(TOOLCHAIN_PATH):$(PATH)

ifneq ($(KERNELRELEASE),)
obj-m += fanctl.o
else

all:
	$(MAKE) -C $(KDIR) M=$(PWD) ARCH=$(CPU) CROSS_COMPILE=$(TOOLCHAIN) modules

clean:
	$(MAKE) -C $(KDIR) M=$(PWD) clean

install:
	$(MAKE) -C $(KDIR) M=$(PWD) INSTALL_MOD_PATH=$(MODPATH) modules_install

endif

.PHONY: all clean install