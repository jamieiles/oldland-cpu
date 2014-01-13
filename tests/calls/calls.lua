require "common"

return run_test({
	elf = "calls",
	max_cycle_count = 1000,
	modes = {"step", "run"},
	testpoints = {
		{ TP_USER, 0 },
		{ TP_USER, 1 },
		{ TP_USER, 2 },
		{ TP_USER, 3 },
		{ TP_USER, 4 },
		{ TP_SUCCESS, 0 }
	}
})
