require "common"

function setup()
	-- Load addr 0x00000000 to get a valid cache line, we should then have
	-- our first few instructions written to the dcache then later flushed.
	target.read32(0)
end
function validate_r1()
	r1 = target.read_reg(1)
	print(string.format("%08x", r1))

	if r1 ~= 0xfeed then return -1 end
end

return run_test({
	elf = "selfmod",
	max_cycle_count = 1000,
	modes = {"step", "run"},
	setup = setup,
	testpoints = {
		{ TP_USER, 0 },
		{ TP_USER, 1 },
		{ TP_SUCCESS, 0, validate_r1 }
	}
})
