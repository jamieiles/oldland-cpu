cmake_minimum_required(VERSION 2.6)
project(Oldland)

include(ExternalProject)

ExternalProject_Add(binutils-oldland
		    SOURCE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/binutils-oldland
		    CONFIGURE_COMMAND ${CMAKE_CURRENT_SOURCE_DIR}/binutils-oldland/configure --prefix=${CMAKE_INSTALL_PREFIX} --target=oldland-elf
		    BUILD_COMMAND ${MAKE})
ExternalProject_Add(bootrom
		    SOURCE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/bootrom
		    DEPENDS binutils-oldland
		    CMAKE_ARGS -DCMAKE_INSTALL_PREFIX:PATH=${CMAKE_INSTALL_PREFIX})
ExternalProject_Add(sim
		    SOURCE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/sim
		    CMAKE_ARGS -DCMAKE_INSTALL_PREFIX:PATH=${CMAKE_INSTALL_PREFIX})
ExternalProject_Add(verif
		    SOURCE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/verif
		    CMAKE_ARGS -DCMAKE_INSTALL_PREFIX:PATH=${CMAKE_INSTALL_PREFIX})
ExternalProject_Add(debugger
		    SOURCE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/debugger
		    CMAKE_ARGS -DCMAKE_INSTALL_PREFIX:PATH=${CMAKE_INSTALL_PREFIX})
