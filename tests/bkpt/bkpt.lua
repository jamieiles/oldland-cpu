require "common"

connect_and_load("bkpt")

expect_testpoints = {
	{ TP_USER, 0 },
	{ TP_USER, 1 },
	{ TP_SUCCESS, 0 },
}

return run_testpoints(expect_testpoints)
