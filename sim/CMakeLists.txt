cmake_minimum_required(VERSION 2.6)
project(OldlandSimulator)
set(CMAKE_C_FLAGS "-ggdb3 -Wall -Werror -O2")
set(CMAKE_C_FLAGS "-DROM_FILE=\\\"${CMAKE_INSTALL_PREFIX}/lib/sim.bin\\\" ${CMAKE_C_FLAGS}")
set(CMAKE_C_FLAGS "-DMICROCODE_FILE=\\\"${CMAKE_INSTALL_PREFIX}/lib/decode.hex\\\" ${CMAKE_C_FLAGS}")

find_package(Threads)

add_executable(oldland-sim debug_uart.c io.c main.c memory.c trace.c cpu.c
	       oldland-instructions.c)

target_link_libraries(oldland-sim ${CMAKE_THREAD_LIBS_INIT})

INSTALL(PROGRAMS ${CMAKE_CURRENT_BINARY_DIR}/oldland-sim DESTINATION bin)
