cmake_minimum_required(VERSION 2.6)
project(OldlandRTLSim)
add_custom_target(keynsham ALL
		  COMMAND iverilog -c ${CMAKE_CURRENT_SOURCE_DIR}/oldland.cf -o ${CMAKE_CURRENT_BINARY_DIR}/keynsham.vvp
		  DEPENDS oldland.cf
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
add_custom_target(rtl ALL DEPENDS keynsham vpi_uart.vpi vpi_debug_stub.vpi oldland-rtlsim)

INSTALL(FILES ${CMAKE_CURRENT_BINARY_DIR}/vpi_uart.vpi DESTINATION lib)
INSTALL(FILES ${CMAKE_CURRENT_BINARY_DIR}/vpi_debug_stub.vpi DESTINATION lib)
INSTALL(FILES ${CMAKE_CURRENT_BINARY_DIR}/keynsham.vvp DESTINATION lib)
INSTALL(PROGRAMS ${CMAKE_CURRENT_BINARY_DIR}/oldland-rtlsim DESTINATION bin)
