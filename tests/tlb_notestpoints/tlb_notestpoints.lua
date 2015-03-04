require "common"

return run_test({
	elf = "tlb_notestpoints",
	max_cycle_count = 128,
	modes = {"run", "step"},
	testpoints = {
		{ TP_SUCCESS, 0 },
	}
})
