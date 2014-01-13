require "common"

function expect0()
	print(string.format("%08x", target.read_reg(0)))
	if target.read_reg(0) ~= 0 then return -1 end
end

function expect8()
	print(string.format("%08x", target.read_reg(0)))
	if target.read_reg(0) ~= 8 then return -1 end
end

function expectffff()
	print(string.format("%08x", target.read_reg(0)))
	if target.read_reg(0) ~= 0xffffffff then return -1 end
end

return run_test({
	elf = "mul",
	max_cycle_count = 1000,
	modes = {"step", "run"},
	testpoints = {
		{ TP_USER, 0, expect0 },
		{ TP_USER, 8, expect8 },
		{ TP_USER, 0xffff, expectffff },
		{ TP_SUCCESS, 0 }
	}
})
