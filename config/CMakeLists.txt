cmake_minimum_required(VERSION 2.6)

add_custom_command(OUTPUT keynsham_defines.v
                   COMMAND ${CMAKE_CURRENT_SOURCE_DIR}/../tools/keynsham/config --verilog ${KEYNSHAM_SOC_CONFIG}
                   DEPENDS ${KEYNSHAM_SOC_CONFIG} ${CMAKE_CURRENT_SOURCE_DIR}/../tools/keynsham/config)

add_custom_command(OUTPUT config.h
                   COMMAND ${CMAKE_CURRENT_SOURCE_DIR}/../tools/keynsham/config --c ${KEYNSHAM_SOC_CONFIG}
                   DEPENDS ${KEYNSHAM_SOC_CONFIG} ${CMAKE_CURRENT_SOURCE_DIR}/../tools/keynsham/config)

add_custom_target(gendefines ALL
                  DEPENDS config.h keynsham_defines.v)
