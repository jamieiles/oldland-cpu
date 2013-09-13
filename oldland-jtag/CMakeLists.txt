cmake_minimum_required(VERSION 2.6)
project(OldlandJTAG)

set(CMAKE_MODULE_PATH ${CMAKE_MODULE_PATH} ${CMAKE_CURRENT_SOURCE_DIR}/CMake/Modules)

set(CMAKE_C_FLAGS "-ggdb3 -Wall -Werror -O2")

add_executable(oldland-jtagd oldland-jtagd.c jtag/jtag.c jtag/jtag-virtual.c)

find_package(libusb-1.0 REQUIRED)
include_directories(${LIBUSB_1_INCLUDE_DIRS})
target_link_libraries(oldland-jtagd ${LIBUSB_1_LIBRARIES})

INSTALL(PROGRAMS ${CMAKE_CURRENT_BINARY_DIR}/oldland-jtagd DESTINATION bin)
