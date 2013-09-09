require "common"

MAX_CYCLE_COUNT = 1000

connect("localhost", "36000")
loadelf("branches")

expect_testpoints = {
	{ TP_SUCCESS, 0 }
}

return run_testpoints(expect_testpoints)
