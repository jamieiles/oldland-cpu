cmake_minimum_required(VERSION 2.6)
project(Oldland)

add_subdirectory(sim)
add_subdirectory(debugger)
include(ExternalProject)
ExternalProject_Add(binutils-oldland
		    SOURCE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/binutils-oldland
		    CONFIGURE_COMMAND ${CMAKE_CURRENT_SOURCE_DIR}/binutils-oldland/configure --prefix=${CMAKE_INSTALL_PREFIX} --target=oldland-elf
		    BUILD_COMMAND ${MAKE})
