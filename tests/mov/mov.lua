require "common"

function validate_r1()
	r1 = target.read_reg(1)

	if r1 ~= 0xdeadbeef then
		print(string.format("unexpected r1 value %08x != 0xdeadbeef", r1))
		return -1
	end
end

function validate_r2()
	r1 = target.read_reg(2)

	if r1 ~= 0x100 then
		print(string.format("unexpected r2 value %08x != 0xdeadbeef", r1))
		return -1
	end
end

function validate_r3()
	r1 = target.read_reg(3)

	if r1 ~= 0xffffffff then
		print(string.format("unexpected r3 value %08x != 0xdeadbeef", r1))
		return -1
	end
end

return run_test({
	elf = "mov",
	max_cycle_count = 1000,
	modes = {"step", "run"},
	testpoints = {
		{ TP_USER, 0, validate_r1 },
		{ TP_USER, 1, validate_r2 },
		{ TP_USER, 2, validate_r3 },
		{ TP_SUCCESS, 0 }
	}
})
