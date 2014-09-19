cmake_minimum_required(VERSION 2.6)
project(OldlandVerif)

set(VERILATOR_INCLUDES
    -I${CMAKE_CURRENT_SOURCE_DIR}/../rtl
    -I${CMAKE_CURRENT_SOURCE_DIR}/../rtl/common
    -I${CMAKE_CURRENT_SOURCE_DIR}/../rtl/keynsham
    -I${CMAKE_CURRENT_SOURCE_DIR}/../rtl/oldland
    -I${CMAKE_CURRENT_SOURCE_DIR}/../rtl/uart
    -I${CMAKE_CURRENT_SOURCE_DIR}/../rtl/spimaster
    -I${CMAKE_CURRENT_SOURCE_DIR}/../rtl/sdram/rtl
    -I${CMAKE_CURRENT_SOURCE_DIR}/common
    -I${CMAKE_CURRENT_SOURCE_DIR}/verilator
    -I${CMAKE_CURRENT_SOURCE_DIR})

set(VERILATOR_FLAGS -DSIMULATION)

add_custom_command(OUTPUT ${CMAKE_CURRENT_BINARY_DIR}/keynsham_defines.v
		   COMMAND ${CMAKE_CURRENT_SOURCE_DIR}/../tools/keynsham/config --verilog > keynsham_defines.v
		   DEPENDS ${CMAKE_CURRENT_SOURCE_DIR}/../config/keynsham.yaml
		   WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR})
add_custom_command(OUTPUT ${CMAKE_CURRENT_BINARY_DIR}/oldland_defines.v
		   COMMAND ${CMAKE_CURRENT_SOURCE_DIR}/../tools/instructions/vdefines ${CMAKE_CURRENT_BINARY_DIR}/oldland_defines.v
		   DEPENDS ${CMAKE_CURRENT_SOURCE_DIR}/../config/instructions.yaml)
add_custom_command(OUTPUT ${CMAKE_CURRENT_BINARY_DIR}/decode.hex
		   COMMAND ${CMAKE_CURRENT_SOURCE_DIR}/../tools/gendecode/gendecode > ${CMAKE_CURRENT_BINARY_DIR}/decode.hex
		   DEPENDS ${CMAKE_CURRENT_SOURCE_DIR}/../config/instructions.yaml)
add_custom_command(OUTPUT ${CMAKE_CURRENT_BINARY_DIR}/oldland-rtlsim
		   COMMAND sed -e "s#%INSTALL_PATH%#${CMAKE_INSTALL_PREFIX}#g" ${CMAKE_CURRENT_SOURCE_DIR}/oldland-rtlsim > ${CMAKE_CURRENT_BINARY_DIR}/oldland-rtlsim
                   DEPENDS ${CMAKE_CURRENT_SOURCE_DIR}/oldland-rtlsim)
add_custom_target(generate
		  DEPENDS ${CMAKE_CURRENT_BINARY_DIR}/oldland-rtlsim ${CMAKE_CURRENT_BINARY_DIR}/keynsham_defines.v ${CMAKE_CURRENT_BINARY_DIR}/oldland_defines.v ${CMAKE_CURRENT_BINARY_DIR}/decode.hex)

add_custom_target(lint ALL
		  DEPENDS generate
		  COMMAND verilator --lint-only ${VERILATOR_FLAGS} -I${CMAKE_CURRENT_SOURCE_DIR} ${VERILATOR_INCLUDES} -D__ICARUS__ oldland_defines.v keynsham_defines.v ${CMAKE_CURRENT_SOURCE_DIR}/../rtl/keynsham/keynsham_soc.v)

INSTALL(FILES ${CMAKE_CURRENT_BINARY_DIR}/decode.hex DESTINATION lib)
INSTALL(PROGRAMS ${CMAKE_CURRENT_BINARY_DIR}/oldland-rtlsim DESTINATION bin)

add_subdirectory(icarus)
add_subdirectory(verilator)
