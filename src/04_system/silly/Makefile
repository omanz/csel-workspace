# Makefile for CMake project with intelligent configuration

TOOLCHAIN_FILE ?= ../../nanopi.cmake
TOOLCHAIN_PATH ?= /buildroot/output/host/usr/bin
CROSS_PREFIX ?= $(TOOLCHAIN_PATH)/aarch64-linux-

# Default target
all: build/build.ninja 
	cmake --build build

# Create build directory and generate build files if needed
build/build.ninja : CMakeLists.txt Makefile $(TOOLCHAIN_FILE)
	cmake --fresh -S . -B build -G "Ninja" \
		-DCMAKE_TOOLCHAIN_FILE=$(TOOLCHAIN_FILE) \
		-DCMAKE_C_COMPILER=$(CROSS_PREFIX)gcc \
		-DCMAKE_CXX_COMPILER=$(CROSS_PREFIX)g++

# Clean build directory
clean:
	rm -rf build

# Rebuild from scratch
rebuild: clean all

# Phony targets (targets that don't represent files)
.PHONY: all clean rebuild