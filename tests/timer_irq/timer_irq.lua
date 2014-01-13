require "common"

return run_test({
	elf = "timer_irq",
	max_cycle_count = 1024,
	modes = {"step", "run"}
})
