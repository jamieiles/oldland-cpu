require "common"

MAX_CYCLE_COUNT = 128

connect("localhost", "36000")
loadelf("swi")

expect_testpoints = {
	{ TP_USER, 0 },
	{ TP_USER, 1 },
	{ TP_SUCCESS, 0 },
}

return run_testpoints(expect_testpoints)
