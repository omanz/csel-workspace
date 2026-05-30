cmake_minimum_required(VERSION 3.28)
project(fanctl_daemon)

include(../../nanopi.cmake)
add_executable(fanctl_daemon main.c oled/ssd1306.c)