require "common"

MAX_CYCLE_COUNT = 128

connect_and_load("exception_irq_disabled")

expect_testpoints = {
	{ TP_USER, 0 },
	{ TP_SUCCESS, 0 },
}

return step_testpoints(expect_testpoints)
