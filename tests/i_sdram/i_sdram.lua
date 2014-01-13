require "common"

return run_test({
	elf = "i_sdram",
	max_cycle_count = 10000,
	modes = {"step", "run"},
	testpoints = {
		{ TP_USER, 0 },
		{ TP_USER, 1 },
		{ TP_SUCCESS, 0 },
	}
})
