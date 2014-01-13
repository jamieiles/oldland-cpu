require "common"

return run_test({
	elf = "crbasic",
	max_cycle_count = 128,
	modes = {"step", "run"}
})
