require "common"

function validate_regs()
	for i = 0, 13 do
		v = target.read_reg(i)
		if v ~= i + 0x100 then
			print(string.format("$r%d expected %08x, got %08x", i, v, i + 0x100))
			return -1
		end
	end
	v = target.read_reg(15)
	if v ~= 15 + 0x100 then
		print(string.format("$r%d expected %08x, got %08x", 15, v, 15 + 0x100))
		return -1
	end

	v = target.read_reg(14)
	if v ~= 0x20001000 then
		print(string.format("$sp expected %08x, got %08x", 0x20001000, v))
		return -1
	end

	v = target.read_cr(2)
	if v ~= 0xf then
		print(string.format("spsr, got %08x, expected 0xf", v))
		return -1
	end

	v = target.read_cr(3)
	if v ~= 0x0defaced then
		print(string.format("psr, got %08x, expected 0x0defaced", v))
		return -1
	end
end

return run_test({
	elf = "stack_save",
	max_cycle_count = 1024,
	modes = {"step", "run"},
	testpoints = {
		{ TP_USER, 0, validate_regs },
		{ TP_SUCCESS, 0 },
	}
})
