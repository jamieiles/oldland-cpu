cmake_minimum_required(VERSION 2.6)
project(OldlandSimulator)

find_package(Threads)

set(CMAKE_C_FLAGS "-ggdb3 -Wall -Werror -O2")
set(CMAKE_C_FLAGS "-DROM_FILE=\\\"${CMAKE_INSTALL_PREFIX}/lib/bootrom.bin\\\" ${CMAKE_C_FLAGS}")
set(CMAKE_C_FLAGS "-I${CMAKE_CURRENT_SOURCE_DIR}/../devicemodels ${CMAKE_C_FLAGS}")
set(CMAKE_C_FLAGS "-include ${CMAKE_CURRENT_BINARY_DIR}/../config/config.h ${CMAKE_C_FLAGS}")
set(CMAKE_C_FLAGS "-I${CMAKE_CURRENT_BINARY_DIR}/ ${CMAKE_C_FLAGS}")
set(CMAKE_C_FLAGS "-DMICROCODE_FILE=\\\"${CMAKE_INSTALL_PREFIX}/lib/decode.hex\\\" ${CMAKE_C_FLAGS}")

add_custom_command(OUTPUT oldland-types.h oldland-instructions.c
		   COMMAND ${CMAKE_CURRENT_SOURCE_DIR}/../tools/instructions/instructions.py
		   DEPENDS ${CMAKE_CURRENT_SOURCE_DIR}/../config/instructions.yaml
		   WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR})

add_executable(oldland-sim debug_uart.c io.c main.c memory.c trace.c cpu.c
	       oldland-instructions.c irq_ctrl.c periodic.c timer.c cache.c
	       oldland-types.h oldland-instructions.c
	       spimaster.c ../devicemodels/uart.c ../devicemodels/jtag.c
	       sdcard.c ../devicemodels/spi_sdcard.c tlb.c)
add_dependencies(oldland-sim gendefines)

target_link_libraries(oldland-sim ${CMAKE_THREAD_LIBS_INIT})

INSTALL(PROGRAMS ${CMAKE_CURRENT_BINARY_DIR}/oldland-sim DESTINATION bin)
