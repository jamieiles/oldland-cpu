require "common"

MAX_CYCLE_COUNT = 1024

connect_and_load("timer_irq")

expect_testpoints = {
	{ TP_SUCCESS, 0 },
}

return run_testpoints(expect_testpoints)
