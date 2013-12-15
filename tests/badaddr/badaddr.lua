require "common"

MAX_CYCLE_COUNT = 128

connect_and_load("badaddr")

expect_testpoints = {
	{ TP_SUCCESS, 0 },
}

return step_testpoints(expect_testpoints)
