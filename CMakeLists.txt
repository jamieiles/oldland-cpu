cmake_minimum_required(VERSION 2.6)
project(Oldland ASM C)

set(KEYNSHAM_SOC_CONFIG de0-nano.yaml CACHE STRING "config file from config to use")

add_subdirectory(config)
add_subdirectory(devicemodels)
add_subdirectory(sim)
add_subdirectory(debugger)
add_subdirectory(verif)
add_subdirectory(bootrom)
add_subdirectory(tests)
add_subdirectory(oldland-jtag)
