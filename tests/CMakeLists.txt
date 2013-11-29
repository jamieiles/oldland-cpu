cmake_minimum_required(VERSION 2.6)

add_subdirectory(addbranch)
add_subdirectory(badaddr)
add_subdirectory(crbasic)
add_subdirectory(swi)
add_subdirectory(illegalinstr)
add_subdirectory(ifetchabort)
add_subdirectory(ldrstr)
add_subdirectory(branches)
add_subdirectory(calls)
add_subdirectory(d_sdram)
add_subdirectory(i_sdram)
add_subdirectory(addcarry)
add_subdirectory(irq)
add_subdirectory(irq_sdram)
add_subdirectory(exception_irq_disabled)
add_subdirectory(timer)
add_subdirectory(timer_irq)
add_subdirectory(selfmod)
add_subdirectory(cpuid)

add_custom_command(OUTPUT ${CMAKE_CURRENT_BINARY_DIR}/oldland-test
		   COMMAND sed -e "s#%TEST_PATH%#${CMAKE_INSTALL_PREFIX}/lib/oldland/tests#g"
			${CMAKE_CURRENT_SOURCE_DIR}/oldland-test >
			${CMAKE_CURRENT_BINARY_DIR}/oldland-test
		   DEPENDS oldland-test)
add_custom_target(test ALL DEPENDS oldland-test)

install(FILES common.lua DESTINATION lib/oldland/tests)
install(FILES terminate.lua DESTINATION lib/oldland/tests)
install(PROGRAMS ${CMAKE_CURRENT_BINARY_DIR}/oldland-test DESTINATION bin)
