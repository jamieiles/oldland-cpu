cmake_minimum_required(VERSION 2.6)
project(OldlandBootROM)

include(CMakeForceCompiler)
set(CMAKE_SYSTEM_NAME none)
cmake_force_c_compiler(oldland-elf-gcc GNU)
set(CMAKE_FIND_ROOT_PATH ${CMAKE_INSTALL_PREFIX})
set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)

set(BOOTLOADERS bootrom sim)
set(BOOTLOADER_BINS)

add_custom_target(buildinfo ALL
		  COMMAND ${CMAKE_CURRENT_SOURCE_DIR}/gen_build >
		  ${CMAKE_CURRENT_BINARY_DIR}/build.s
		  WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR})
add_custom_command(OUTPUT keynsham.dts
		   COMMAND ${CMAKE_CURRENT_SOURCE_DIR}/../tools/keynsham/gendts > ${CMAKE_CURRENT_BINARY_DIR}/keynsham.dts
		   DEPENDS ${CMAKE_CURRENT_SOURCE_DIR}/../config/keynsham.yaml)
add_custom_command(OUTPUT keynsham.dtb
		   COMMAND dtc -I dts -O dtb -o ${CMAKE_CURRENT_BINARY_DIR}/keynsham.dtb ${CMAKE_CURRENT_BINARY_DIR}/keynsham.dts
		   DEPENDS ${CMAKE_CURRENT_BINARY_DIR}/keynsham.dts)
add_custom_command(OUTPUT build.o
		   COMMAND oldland-elf-as ${CMAKE_CURRENT_BINARY_DIR}/build.s -o build.o
		   DEPENDS buildinfo ${CMAKE_CURRENT_BINARY_DIR}/build.s ${CMAKE_CURRENT_BINARY_DIR}/keynsham.dtb)

foreach(bootloader ${BOOTLOADERS})
add_custom_command(OUTPUT ${bootloader}
		   COMMAND oldland-elf-ld ${bootloader}.o build.o -o ${bootloader}
			-T ${CMAKE_CURRENT_SOURCE_DIR}/bootrom.x
		   DEPENDS ${bootloader}.o build.o)
add_custom_command(OUTPUT ${bootloader}.o
		   COMMAND oldland-elf-as ${CMAKE_CURRENT_SOURCE_DIR}/${bootloader}.s -o ${bootloader}.o
		   DEPENDS ${bootloader}.s)
add_custom_command(OUTPUT ${bootloader}.bin
		   COMMAND oldland-elf-objcopy ${bootloader} ${bootloader}.bin -O binary --pad-to=0x200
		   DEPENDS ${bootloader})
add_custom_command(OUTPUT ${bootloader}.hex
		   COMMAND oldland-elf-objcopy ${bootloader} ${bootloader}.hex -O verilog --pad-to=0x1000
		   DEPENDS ${bootloader})
add_custom_command(OUTPUT ${bootloader}.ihex
		   COMMAND ${CMAKE_CURRENT_SOURCE_DIR}/../tools/makeramfile/makeramfile ${bootloader}.bin ${bootloader}.ihex
		   DEPENDS ${bootloader}.bin)
set(BOOTLOADER_BINS ${BOOTLOADER_BINS} ${bootloader}.hex ${bootloader}.ihex)
INSTALL(FILES ${CMAKE_CURRENT_BINARY_DIR}/${bootloader}.hex DESTINATION lib)
INSTALL(FILES ${CMAKE_CURRENT_BINARY_DIR}/${bootloader}.ihex DESTINATION lib)
INSTALL(FILES ${CMAKE_CURRENT_BINARY_DIR}/${bootloader}.bin DESTINATION lib)
endforeach(bootloader)

add_custom_target(bootrom-bin ALL DEPENDS ${BOOTLOADER_BINS})
