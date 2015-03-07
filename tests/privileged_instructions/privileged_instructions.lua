require "common"

return run_test({
	elf = "privileged_instructions",
	max_cycle_count = 128,
	modes = {"step", "run"},
	testpoints = {
		-- cache aborts
		{ TP_USER, 0x100 },
		{ TP_USER, 0 },
		-- rfe aborts
		{ TP_USER, 0x100 },
		{ TP_USER, 1 },
		-- scr aborts
		{ TP_USER, 0x100 },
		{ TP_USER, 2 },
		-- gcr aborts
		{ TP_USER, 0x100 },
		{ TP_USER, 3 },

		{ TP_SUCCESS, 0 },
	}
})
