require "common"

MAX_CYCLE_COUNT = 128

connect("localhost", "36000")
loadelf("badaddr")

expect_testpoints = {
	{ TP_SUCCESS, 0 },
}

return run_testpoints(expect_testpoints)
