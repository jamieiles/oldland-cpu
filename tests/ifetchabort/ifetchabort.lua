require "common"

MAX_CYCLE_COUNT = 128

connect_and_load("ifetchabort")

expect_testpoints = {
	{ TP_USER, 0 },
	{ TP_SUCCESS, 0 },
}

return run_testpoints(expect_testpoints)
