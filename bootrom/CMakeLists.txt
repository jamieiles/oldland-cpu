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

foreach(bootloader ${BOOTLOADERS})
add_custom_command(OUTPUT ${bootloader}
		   COMMAND oldland-elf-as ${CMAKE_CURRENT_SOURCE_DIR}/${bootloader}.s -o ${bootloader}
		   DEPENDS ${bootloader}.s)
add_custom_command(OUTPUT ${bootloader}.bin
		   COMMAND oldland-elf-objcopy ${bootloader} ${bootloader}.bin -O binary --pad-to=0x100
		   DEPENDS ${bootloader})
add_custom_command(OUTPUT ${bootloader}.hex
		   COMMAND oldland-elf-objcopy ${bootloader} ${bootloader}.hex -O verilog --pad-to=0x100
		   DEPENDS ${bootloader})
add_custom_command(OUTPUT ${bootloader}.ihex
		   COMMAND ${CMAKE_CURRENT_SOURCE_DIR}/../tools/makeramfile/makeramfile ${bootloader}.bin ${bootloader}.ihex
		   DEPENDS ${bootloader}.bin)
set(BOOTLOADER_BINS ${BOOTLOADER_BINS} ${bootloader}.hex ${bootloader}.ihex)
INSTALL(FILES ${CMAKE_CURRENT_BINARY_DIR}/${bootloader}.hex DESTINATION lib)
INSTALL(FILES ${CMAKE_CURRENT_BINARY_DIR}/${bootloader}.ihex DESTINATION lib)
endforeach(bootloader)

add_custom_target(bootrom-bin ALL DEPENDS ${BOOTLOADER_BINS})
