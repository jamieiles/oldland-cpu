require "common"

MAX_CYCLE_COUNT = 128

connect_and_load("cpuid")

function validate_cpuid()
	for i = 0, 4 do
		c = target.read_cpuid(i)
		r = target.read_reg(i)

		if c ~= r then return -1 end
	end

	if target.read_reg(0) == 0 then return -1 end
end

expect_testpoints = {
	{ TP_SUCCESS, 0, validate_cpuid }
}

return run_testpoints(expect_testpoints)
