cmake_minimum_required(VERSION 2.6)
project(OldlandSimulator)

set(CMAKE_C_FLAGS "-ggdb3 -Wall -Werror -O2")
add_executable(sim debug_uart.c io.c main.c memory.c)
