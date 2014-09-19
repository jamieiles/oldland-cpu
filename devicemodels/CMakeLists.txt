cmake_minimum_required(VERSION 2.6)
project(devicemodels)

find_package(Threads)

set(CMAKE_C_FLAGS "-ggdb3 -Wall -Werror -O2")

add_library(devicemodels jtag.c spi_sdcard.c uart.c)
