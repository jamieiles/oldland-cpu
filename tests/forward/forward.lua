require "common"

return run_test({
	elf = "forward",
	max_cycle_count = 128,
	modes = {"step", "run"}
})
