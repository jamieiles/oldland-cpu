cmake_minimum_required(VERSION 2.6)

set(CMAKE_SYSTEM_NAME none)
set(CMAKE_SYSTEM_PROCESSOR oldland)
set(CMAKE_C_COMPILER oldland-elf-gcc)
set(CMAKE_ASM_COMPILER oldland-elf-as)

set(CMAKE_C_FLAGS "-Wall -Werror -ffreestanding -O2 -ggdb3 -std=gnu99 -nostdinc")
set(CMAKE_ASM_FLAGS "-I${CMAKE_CURRENT_SOURCE_DIR}")

SET(CMAKE_SHARED_LIBRARY_LINK_C_FLAGS "-nostdlib -T ${CMAKE_CURRENT_SOURCE_DIR}/bootrom.x -Wl,-EL -lgcc")

add_custom_command(OUTPUT keynsham.dts
		   COMMAND ${CMAKE_CURRENT_SOURCE_DIR}/../tools/keynsham/gendts ${KEYNSHAM_SOC_CONFIG} > ${CMAKE_CURRENT_BINARY_DIR}/keynsham.dts
		   DEPENDS ${CMAKE_CURRENT_SOURCE_DIR}/../config/${KEYNSHAM_SOC_CONFIG})
add_custom_command(OUTPUT keynsham.dtb
		   COMMAND dtc -I dts -O dtb -o ${CMAKE_CURRENT_BINARY_DIR}/keynsham.dtb ${CMAKE_CURRENT_BINARY_DIR}/keynsham.dts
		   DEPENDS ${CMAKE_CURRENT_BINARY_DIR}/keynsham.dts)
add_custom_command(OUTPUT ${CMAKE_CURRENT_BINARY_DIR}/build.s
		   COMMAND ${CMAKE_CURRENT_SOURCE_DIR}/gen_build > ${CMAKE_CURRENT_BINARY_DIR}/build.s
		   WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
		   DEPENDS ${CMAKE_CURRENT_BINARY_DIR}/keynsham.dtb)

add_executable(bootrom
	       ${CMAKE_CURRENT_BINARY_DIR}/build.s
	       entry.s
	       sdram.s
	       kernel.c
	       uart.c
	       string.c
	       sdcard.c)

add_custom_command(OUTPUT bootrom.bin
		   COMMAND oldland-elf-objcopy bootrom bootrom.bin -O binary --pad-to=0x4000
		   DEPENDS bootrom)
add_custom_command(OUTPUT bootrom.hex
		   COMMAND oldland-elf-objcopy bootrom bootrom.hex -O verilog --pad-to=0x4000
		   DEPENDS bootrom)
add_custom_command(OUTPUT bootrom.ihex
		   COMMAND ${CMAKE_CURRENT_SOURCE_DIR}/../tools/makeramfile/makeramfile bootrom.bin bootrom.ihex
		   DEPENDS bootrom.bin)
add_custom_target(hexbootroms ALL
		  DEPENDS bootrom.ihex bootrom.hex bootrom.bin)
INSTALL(FILES ${CMAKE_CURRENT_BINARY_DIR}/bootrom.hex DESTINATION lib)
INSTALL(FILES ${CMAKE_CURRENT_BINARY_DIR}/bootrom.ihex DESTINATION lib)
INSTALL(FILES ${CMAKE_CURRENT_BINARY_DIR}/bootrom.bin DESTINATION lib)

add_custom_target(bootrom-bin ALL DEPENDS bootrom)
