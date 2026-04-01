DIRS=$(filter-out Makefile include, $(wildcard *))

all clean install:
	for dir in $(DIRS); do $(MAKE) $@ -C $$dir; done

