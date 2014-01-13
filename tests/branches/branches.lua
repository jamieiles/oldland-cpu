require "common"

return run_test({
	elf = "branches",
	max_cycle_count = 1000,
	modes = {"step", "run"}
})
