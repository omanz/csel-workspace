cmake_minimum_required(VERSION 3.28)
project(fanctl_cli)

include(../../nanopi.cmake)
add_executable(fanctl_cli fanctl_cli.c)