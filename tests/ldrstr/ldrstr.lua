require "common"

MAX_CYCLE_COUNT = 1000

connect_and_load("ldrstr")

expect_testpoints = {
	{ TP_SUCCESS, 0 }
}

return run_testpoints(expect_testpoints)
