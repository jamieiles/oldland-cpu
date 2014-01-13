require "common"

return run_test({
	elf = "exception_irq_disabled",
	max_cycle_count = 128,
	modes = {"step", "run"},
	testpoints = {
		{ TP_USER, 0 },
		{ TP_SUCCESS, 0 },
	}
})
