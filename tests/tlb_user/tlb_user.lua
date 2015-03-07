require "common"

return run_test({
	elf = "tlb_user",
	max_cycle_count = 256,
	modes = {"step", "run"},
	testpoints = {
		-- Supervisor accesses to user only pages
		{ TP_USER, 0x100 },
		{ TP_USER, 0 },
		{ TP_USER, 0x100 },
		{ TP_USER, 1 },
		-- Supervisor accesses to supervisor only pages 
		{ TP_USER, 2 },
		{ TP_USER, 3 },
		-- User accesses to user only pages 
		{ TP_USER, 4 },
		{ TP_USER, 5 },
		-- User accesses to supervisor only pages
		{ TP_USER, 0x100 },
		{ TP_USER, 6 },
		{ TP_USER, 0x100 },
		{ TP_USER, 7 },
		-- Done
		{ TP_SUCCESS, 0 },
	}
})
