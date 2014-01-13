require "common"

function validate_cpuid()
	for i = 0, 4 do
		c = target.read_cpuid(i)
		r = target.read_reg(i)

		if c ~= r then return -1 end
	end

	if target.read_reg(0) == 0 then return -1 end
end

return run_test({
	elf = "cpuid",
	max_cycle_count = 128,
	modes = {"step", "run"},
	testpoints = {
		{ TP_SUCCESS, 0, validate_cpuid }
	}
})
