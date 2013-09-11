require "common"

MAX_CYCLE_COUNT = 1000

connect("localhost", "36000")
loadelf("calls")

expect_testpoints = {
	{ TP_USER, 0 },
	{ TP_USER, 1 },
	{ TP_USER, 2 },
	{ TP_USER, 3 },
	{ TP_USER, 4 },
	{ TP_SUCCESS, 0 }
}

return run_testpoints(expect_testpoints)
