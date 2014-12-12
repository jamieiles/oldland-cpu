cmake_minimum_required(VERSION 2.6)
project(OldlandVerilatorSim)

option(OPTIMIZE_VERILATOR "Enable verilator -O3, faster model, slower builds" OFF)
option(TRACE_VERILATOR "Enable tracing in verilator model" OFF)

set(VERILATOR_FLAGS
    --cc -DSIMULATION=1 -DUSE_DEBUG_UART=1
    -DOLDLAND_ROM_PATH=\\\"${CMAKE_INSTALL_PREFIX}/lib/\\\")

if(TRACE_VERILATOR)
set(VERILATOR_FLAGS ${VERILATOR_FLAGS} --trace -DVERILATOR_TRACE -CFLAGS "-DVERILATOR_TRACE")
endif(TRACE_VERILATOR)

set(VERILATOR_INCLUDES
    -I${CMAKE_CURRENT_SOURCE_DIR}/..
    -I${CMAKE_CURRENT_SOURCE_DIR}/../common
    -I${CMAKE_CURRENT_SOURCE_DIR}/../../rtl/keynsham
    -I${CMAKE_CURRENT_SOURCE_DIR}/../../rtl/oldland
    -I${CMAKE_CURRENT_SOURCE_DIR}/../../rtl/common
    -I${CMAKE_CURRENT_SOURCE_DIR}/../../rtl/spimaster
    -I${CMAKE_CURRENT_SOURCE_DIR}/../../rtl/sdram/rtl
    -I${CMAKE_CURRENT_BINARY_DIR}/../../config)
set(VERILATOR_LIBS
    ${CMAKE_CURRENT_BINARY_DIR}/../../devicemodels/libdevicemodels.a)
set(GENERATED_FILES
    ${CMAKE_CURRENT_BINARY_DIR}/../oldland_defines.v
    ${CMAKE_CURRENT_BINARY_DIR}/../../config/keynsham_defines.v)
set(CPP_SOURCES
    debug.cpp
    uart.cpp
    spi.cpp)
set(LINK_FLAGS "-pthread")

if(OPTIMIZE_VERILATOR)
set(VERILATOR_MAKE_OPTS OPT=-O3)
endif(OPTIMIZE_VERILATOR)

add_custom_target(genverilator ALL
		  COMMAND verilator verilator_toplevel.v --exe ${CMAKE_CURRENT_SOURCE_DIR}/verilator_model.cpp ${CPP_SOURCES} ${GENERATED_FILES} ${VERILATOR_FLAGS} ${VERILATOR_INCLUDES} ${VERILATOR_LIBS} -o oldland-verilator --Mdir ${CMAKE_CURRENT_BINARY_DIR}/obj_dir
		  DEPENDS generate gendefines verilator_toplevel.v verilator_model.cpp
		  WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR})
add_custom_target(buildverilator ALL
		  COMMAND USER_LDFLAGS="${LINK_FLAGS}" $(MAKE) -f Vverilator_toplevel.mk ${VERILATOR_MAKE_OPTS}
		  DEPENDS genverilator
		  WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/obj_dir)
INSTALL(PROGRAMS ${CMAKE_CURRENT_BINARY_DIR}/obj_dir/oldland-verilator DESTINATION lib)
