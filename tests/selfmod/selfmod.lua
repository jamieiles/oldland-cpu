require "common"

function validate_r1()
	r1 = target.read_reg(1)
	print(string.format("%08x", r1))

	if r1 ~= 0xfeed then return -1 end
end

return run_test({
	elf = "selfmod",
	max_cycle_count = 1000,
	modes = {"step", "run"},
	testpoints = {
		{ TP_USER, 0 },
		{ TP_USER, 1 },
		{ TP_SUCCESS, 0, validate_r1 }
	}
})
