require "common"

function validate_sdram()
	addr = 0x20000000
	data = ""
	repeat
		v = target.read8(addr)
		addr = addr + 1
		if v > 0 then data = data .. string.format("%c", v) end
	until v == 0

	if data ~= "Hello, world!" then
		print(string.format("Unexpected output \"%s\"", data))
		return -1
	end
end

return run_test({
	elf = "d_sdram",
	max_cycle_count = 1000,
	modes = {"step", "run"},
	testpoints = {
		{ TP_USER, 0, validate_sdram },
		{ TP_SUCCESS, 0 },
	}
})
