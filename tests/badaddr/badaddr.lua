require "common"

return run_test({
	elf = "badaddr",
	max_cycle_count = 128,
	modes = {"step", "run"}
})
