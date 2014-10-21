cmake_minimum_required(VERSION 2.6)
project(OldlandRTLSim)

option(DEBUG_UART "Enable fast, debug uart." OFF)

set(IVERILOG_FLAGS
    -Wall
    -Wno-sensitivity-entire-array
    -I${CMAKE_CURRENT_BINARY_DIR}
    -I${CMAKE_CURRENT_BINARY_DIR}/../../config
    -DOLDLAND_ROM_PATH=\\\"${CMAKE_INSTALL_PREFIX}/lib/\\\")

set(VPI_FLAGS
    -lpthread
    -I${CMAKE_CURRENT_SOURCE_DIR}/../../devicemodels)

if(DEBUG_UART)
set(IVERILOG_FLAGS ${IVERILOG_FLAGS} -DUSE_DEBUG_UART)
endif(DEBUG_UART)

add_custom_target(keynsham ALL
		  COMMAND BUILD_DIR=${CMAKE_CURRENT_BINARY_DIR}
			iverilog ${IVERILOG_FLAGS} -c ${CMAKE_CURRENT_SOURCE_DIR}/oldland.cf
			-o ${CMAKE_CURRENT_BINARY_DIR}/keynsham.vvp
		  DEPENDS generate oldland.cf
		  WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR})
add_custom_command(OUTPUT vpi_uart.vpi
		   COMMAND iverilog-vpi ${VPI_FLAGS} ${CMAKE_CURRENT_SOURCE_DIR}/vpi_uart.c ${CMAKE_CURRENT_SOURCE_DIR}/../../devicemodels/uart.c
		   DEPENDS vpi_uart.c)
add_custom_command(OUTPUT vpi_debug_stub.vpi
		   COMMAND iverilog-vpi ${VPI_FLAGS} ${CMAKE_CURRENT_SOURCE_DIR}/vpi_debug_stub.c ${CMAKE_CURRENT_SOURCE_DIR}/../../devicemodels/jtag.c
		   DEPENDS vpi_debug_stub.c)
add_custom_command(OUTPUT vpi_spislave.vpi
		   COMMAND iverilog-vpi ${VPI_FLAGS} ${CMAKE_CURRENT_SOURCE_DIR}/vpi_spislave.c ${CMAKE_CURRENT_SOURCE_DIR}/../../devicemodels/spi_sdcard.c
		   DEPENDS vpi_spislave.c ../../devicemodels/spi_sdcard.c)
add_custom_target(rtl ALL DEPENDS generate keynsham vpi_uart.vpi vpi_debug_stub.vpi vpi_spislave.vpi)

INSTALL(FILES ${CMAKE_CURRENT_BINARY_DIR}/vpi_uart.vpi DESTINATION lib)
INSTALL(FILES ${CMAKE_CURRENT_BINARY_DIR}/vpi_debug_stub.vpi DESTINATION lib)
INSTALL(FILES ${CMAKE_CURRENT_BINARY_DIR}/vpi_spislave.vpi DESTINATION lib)
INSTALL(FILES ${CMAKE_CURRENT_BINARY_DIR}/keynsham.vvp DESTINATION lib)
