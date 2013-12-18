require "common"

MAX_CYCLE_COUNT = 1000

connect_and_load("selfmod")

function validate_r1()
	r1 = target.read_reg(1)
	print(string.format("%08x", r1))

	if r1 ~= 0xfeed then return -1 end
end

expect_testpoints = {
	{ TP_USER, 0 },
	{ TP_USER, 1 },
	{ TP_SUCCESS, 0, validate_r1 }
}

return step_testpoints(expect_testpoints)
