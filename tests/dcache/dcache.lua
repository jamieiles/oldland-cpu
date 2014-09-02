require "common"

function validate_sdram()
	addr = 0x20000000
	data = ""

        for addr = 0x20000000, 0x20000000 + 32768 - 1024, 1024 do
		v = target.read32(addr)
                if v ~= addr then
                    print(string.format("unexpected value, %x!=%x", v, addr))
                    return -1
                end
        end
end

return run_test({
	elf = "dcache",
	max_cycle_count = 1000,
	modes = {"step", "run"},
	testpoints = {
		{ TP_USER, 0, validate_sdram },
		{ TP_SUCCESS, 0 },
	}
})
