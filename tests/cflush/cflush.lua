require "common"

function validate_sdram()
	addr = 0x20000000
	data = ""

        for addr = 0x20000000, 0x20000000 + 16, 4 do
		v = target.read32(addr)
		print(string.format("  %08x %08x", addr, v))
                if v ~= addr - 0x20000000 then
                    print(string.format("unexpected value, %x!=%x", v, addr - 0x20000000))
		    --return -1
                end
        end
end

return run_test({
	elf = "cflush",
	max_cycle_count = 1000,
	modes = {"step", "run"},
	testpoints = {
		{ TP_USER, 0, validate_sdram },
		{ TP_SUCCESS, 0 },
	}
})
