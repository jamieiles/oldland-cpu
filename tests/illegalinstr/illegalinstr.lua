require "common"

return run_test({
	elf = "illegalinstr",
	max_cycle_count = 128,
	modes = {"step", "run"}
})
