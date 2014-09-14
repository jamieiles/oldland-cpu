cmake_minimum_required(VERSION 2.6)
project(OldlandRTLSim)

option(DEBUG_UART "Enable fast, debug uart." OFF)

set(IVERILOG_FLAGS
    -Wall
    -I${CMAKE_CURRENT_BINARY_DIR}
    -DOLDLAND_ROM_PATH=\\\"${CMAKE_INSTALL_PREFIX}/lib/\\\")

set(VPI_FLAGS
    -lpthread
    -I${CMAKE_CURRENT_SOURCE_DIR}/../devicemodels)

if(DEBUG_UART)
set(IVERILOG_FLAGS ${IVERILOG_FLAGS} -DUSE_DEBUG_UART)
endif(DEBUG_UART)

add_custom_target(keynsham ALL
		  COMMAND BUILD_DIR=${CMAKE_CURRENT_BINARY_DIR}
			iverilog ${IVERILOG_FLAGS} -c ${CMAKE_CURRENT_SOURCE_DIR}/oldland.cf
			-o ${CMAKE_CURRENT_BINARY_DIR}/keynsham.vvp
		  DEPENDS oldland.cf ${CMAKE_CURRENT_BINARY_DIR}/oldland_defines.v ${CMAKE_CURRENT_BINARY_DIR}/keynsham_defines.v
		  WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR})
add_custom_command(OUTPUT vpi_uart.vpi
		   COMMAND iverilog-vpi ${VPI_FLAGS} ${CMAKE_CURRENT_SOURCE_DIR}/vpi_uart.c ${CMAKE_CURRENT_SOURCE_DIR}/../devicemodels/uart.c
		   DEPENDS vpi_uart.c)
add_custom_command(OUTPUT vpi_debug_stub.vpi
		   COMMAND iverilog-vpi ${VPI_FLAGS} ${CMAKE_CURRENT_SOURCE_DIR}/vpi_debug_stub.c ${CMAKE_CURRENT_SOURCE_DIR}/../devicemodels/jtag.c
		   DEPENDS vpi_debug_stub.c)
add_custom_command(OUTPUT vpi_spislave.vpi
		   COMMAND iverilog-vpi ${VPI_FLAGS} ${CMAKE_CURRENT_SOURCE_DIR}/vpi_spislave.c ${CMAKE_CURRENT_SOURCE_DIR}/../devicemodels/spi_sdcard.c
		   DEPENDS vpi_spislave.c ../devicemodels/spi_sdcard.c)
add_custom_command(OUTPUT oldland-rtlsim
		   COMMAND sed -e "s#%INSTALL_PATH%#${CMAKE_INSTALL_PREFIX}#g" ${CMAKE_CURRENT_SOURCE_DIR}/oldland-rtlsim > ${CMAKE_CURRENT_BINARY_DIR}/oldland-rtlsim
		   DEPENDS oldland-rtlsim)
add_custom_command(OUTPUT oldland_defines.v
		   COMMAND ${CMAKE_CURRENT_SOURCE_DIR}/../tools/instructions/vdefines ${CMAKE_CURRENT_BINARY_DIR}/oldland_defines.v
		   DEPENDS ${CMAKE_CURRENT_SOURCE_DIR}/../config/instructions.yaml)
add_custom_command(OUTPUT ${CMAKE_CURRENT_BINARY_DIR}/decode.hex
		   COMMAND ${CMAKE_CURRENT_SOURCE_DIR}/../tools/gendecode/gendecode > ${CMAKE_CURRENT_BINARY_DIR}/decode.hex
		   DEPENDS ${CMAKE_CURRENT_SOURCE_DIR}/../config/instructions.yaml)
add_custom_command(OUTPUT keynsham_defines.v
		   COMMAND ${CMAKE_CURRENT_SOURCE_DIR}/../tools/keynsham/config --verilog > keynsham_defines.v
		   DEPENDS ${CMAKE_CURRENT_SOURCE_DIR}/../config/keynsham.yaml
		   WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR})
add_custom_target(rtl ALL DEPENDS ${CMAKE_CURRENT_BINARY_DIR}/decode.hex keynsham_defines.v oldland_defines.v keynsham vpi_uart.vpi vpi_debug_stub.vpi vpi_spislave.vpi oldland-rtlsim)

set(VERILATOR_INCLUDES
    -I${CMAKE_CURRENT_SOURCE_DIR}/../rtl
    -I${CMAKE_CURRENT_SOURCE_DIR}/../rtl/common
    -I${CMAKE_CURRENT_SOURCE_DIR}/../rtl/keynsham
    -I${CMAKE_CURRENT_SOURCE_DIR}/../rtl/oldland
    -I${CMAKE_CURRENT_SOURCE_DIR}/../rtl/uart
    -I${CMAKE_CURRENT_SOURCE_DIR}/../rtl/spimaster
    -I${CMAKE_CURRENT_SOURCE_DIR}/../rtl/sdram/rtl
    -I${CMAKE_CURRENT_SOURCE_DIR})

add_custom_target(lint ALL
		  DEPENDS ${CMAKE_CURRENT_BINARY_DIR}/keynsham_defines.v ${CMAKE_CURRENT_BINARY_DIR}/oldland_defines.v
		  COMMAND verilator --lint-only ${VERILATOR_FLAGS} -I${CMAKE_CURRENT_SOURCE_DIR} ${VERILATOR_INCLUDES} -D__ICARUS__ oldland_defines.v keynsham_defines.v ${CMAKE_CURRENT_SOURCE_DIR}/../rtl/keynsham/keynsham_soc.v)

INSTALL(FILES ${CMAKE_CURRENT_BINARY_DIR}/vpi_uart.vpi DESTINATION lib)
INSTALL(FILES ${CMAKE_CURRENT_BINARY_DIR}/vpi_debug_stub.vpi DESTINATION lib)
INSTALL(FILES ${CMAKE_CURRENT_BINARY_DIR}/vpi_spislave.vpi DESTINATION lib)
INSTALL(FILES ${CMAKE_CURRENT_BINARY_DIR}/keynsham.vvp DESTINATION lib)
INSTALL(FILES ${CMAKE_CURRENT_BINARY_DIR}/decode.hex DESTINATION lib)
INSTALL(PROGRAMS ${CMAKE_CURRENT_BINARY_DIR}/oldland-rtlsim DESTINATION bin)
