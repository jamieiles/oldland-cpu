cmake_minimum_required(VERSION 2.6)
project(OldlandConfig)

add_custom_command(OUTPUT keynsham_defines.v
                   COMMAND ${CMAKE_CURRENT_SOURCE_DIR}/../tools/keynsham/config --verilog
                   DEPENDS keynsham.yaml ${CMAKE_CURRENT_SOURCE_DIR}/../tools/keynsham/config)

add_custom_command(OUTPUT config.h
                   COMMAND ${CMAKE_CURRENT_SOURCE_DIR}/../tools/keynsham/config --c
                   DEPENDS keynsham.yaml ${CMAKE_CURRENT_SOURCE_DIR}/../tools/keynsham/config)

add_custom_target(gendefines ALL
                  DEPENDS config.h keynsham_defines.v)
