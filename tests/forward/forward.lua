require "common"

connect_and_load("forward")

expect_testpoints = {
	{ TP_SUCCESS, 0 }
}

return run_testpoints(expect_testpoints)
