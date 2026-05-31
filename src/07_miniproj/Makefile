TARGET_BIN   = /rootfs/usr/bin
TARGET_LIB   = /rootfs/usr/lib
TARGET_INITD = /rootfs/etc/init.d

DIRS = module daemon app_cli

all clean:
	for dir in $(DIRS); do $(MAKE) $@ -C $$dir; done

install: all
	install -d $(TARGET_BIN) $(TARGET_LIB) $(TARGET_INITD)
	install -m 755 module/fanctl.ko             $(TARGET_LIB)/fanctl.ko
	install -m 755 daemon/build/fanctl_daemon   $(TARGET_BIN)/fanctl_daemon
	install -m 755 app_cli/build/fanctl_cli     $(TARGET_BIN)/fanctl_cli
	install -m 755 daemon/S60fanctl             $(TARGET_INITD)/S60fanctl

.PHONY: all clean install