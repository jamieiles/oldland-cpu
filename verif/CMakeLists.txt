cmake_minimum_required(VERSION 2.6)
project(OldlandRTLSim)
add_custom_target(keynsham ALL
		  COMMAND BUILD_DIR=${CMAKE_CURRENT_BINARY_DIR}
			iverilog -Wall -c ${CMAKE_CURRENT_SOURCE_DIR}/oldland.cf
			-I${CMAKE_CURRENT_BINARY_DIR}
			-DOLDLAND_ROM_PATH=\\\"${CMAKE_INSTALL_PREFIX}/lib/\\\"
			-o ${CMAKE_CURRENT_BINARY_DIR}/keynsham.vvp
		  DEPENDS oldland.cf ${CMAKE_CURRENT_BINARY_DIR}/oldland_defines.v ${CMAKE_CURRENT_BINARY_DIR}/keynsham_defines.v
		  WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR})
add_custom_command(OUTPUT vpi_uart.vpi
		   COMMAND iverilog-vpi -lpthread ${CMAKE_CURRENT_SOURCE_DIR}/vpi_uart.c
		   DEPENDS vpi_uart.c)
add_custom_command(OUTPUT vpi_debug_stub.vpi
		   COMMAND iverilog-vpi -lpthread ${CMAKE_CURRENT_SOURCE_DIR}/vpi_debug_stub.c
		   DEPENDS vpi_debug_stub.c)
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
add_custom_target(rtl ALL DEPENDS ${CMAKE_CURRENT_BINARY_DIR}/decode.hex keynsham_defines.v oldland_defines.v keynsham vpi_uart.vpi vpi_debug_stub.vpi oldland-rtlsim)

INSTALL(FILES ${CMAKE_CURRENT_BINARY_DIR}/vpi_uart.vpi DESTINATION lib)
INSTALL(FILES ${CMAKE_CURRENT_BINARY_DIR}/vpi_debug_stub.vpi DESTINATION lib)
INSTALL(FILES ${CMAKE_CURRENT_BINARY_DIR}/keynsham.vvp DESTINATION lib)
INSTALL(FILES ${CMAKE_CURRENT_BINARY_DIR}/decode.hex DESTINATION lib)
INSTALL(PROGRAMS ${CMAKE_CURRENT_BINARY_DIR}/oldland-rtlsim DESTINATION bin)
