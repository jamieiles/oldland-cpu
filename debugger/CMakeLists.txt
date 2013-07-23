cmake_minimum_required(VERSION 2.6)
project(OldlandDebugger)
set(CMAKE_C_FLAGS "-ggdb3 -Wall -Werror -O2")
add_executable(oldland-debug debugger.c)

INSTALL(PROGRAMS ${CMAKE_CURRENT_BINARY_DIR}/oldland-debug DESTINATION bin)
