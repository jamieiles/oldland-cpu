cmake_minimum_required(VERSION 2.6)
project(OldlandDebugger)
set(CMAKE_MODULE_PATH ${CMAKE_MODULE_PATH} ${CMAKE_CURRENT_SOURCE_DIR}/CMake/Modules)
set(CMAKE_C_FLAGS "-I${CMAKE_CURRENT_BINARY_DIR} ${CMAKE_C_FLAGS}")
set(CMAKE_C_FLAGS "-ggdb3 -Wall -Werror -O2 -DINSTALL_PATH=\\\"${CMAKE_INSTALL_PREFIX}\\\" ${CMAKE_C_FLAGS}")

find_package(Lua52 REQUIRED)
include_directories(${LUA_INCLUDE_DIR})

find_package(Readline REQUIRED)
include_directories(${READLINE_INCLUDE_DIRS})

add_custom_command(OUTPUT oldland-types.h oldland-instructions.c
		   COMMAND ${CMAKE_CURRENT_SOURCE_DIR}/../tools/instructions/instructions.py
		   DEPENDS ${CMAKE_CURRENT_SOURCE_DIR}/../config/instructions.yaml
		   WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR})
add_executable(oldland-debug debugger.c loadelf.c regcache.c
	       oldland-instructions.c breakpoint.c)
target_link_libraries(oldland-debug ${LUA_LIBRARIES})
target_link_libraries(oldland-debug ${READLINE_LIBRARY})

INSTALL(PROGRAMS ${CMAKE_CURRENT_BINARY_DIR}/oldland-debug DESTINATION bin)
INSTALL(FILES ${CMAKE_CURRENT_SOURCE_DIR}/oldland-debug-ui.lua DESTINATION libexec)
