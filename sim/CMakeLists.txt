cmake_minimum_required(VERSION 2.6)
project(OldlandSimulator)
set(CMAKE_MODULE_PATH ${CMAKE_MODULE_PATH} ${CMAKE_CURRENT_SOURCE_DIR}/CMake/Modules)
set(CMAKE_C_FLAGS "-ggdb3 -Wall -Werror -O2")
add_executable(oldland-sim debug_uart.c io.c main.c memory.c trace.c cpu.c
	       oldland-instructions.c)

find_package(Lua52)
if (LUA52_FOUND)
	include_directories(${LUA_INCLUDE_DIRS})
	target_link_libraries(oldland-sim ${LUA_LIBRARIES})
endif (LUA52_FOUND)

INSTALL(PROGRAMS ${CMAKE_CURRENT_BINARY_DIR}/oldland-sim DESTINATION bin)
