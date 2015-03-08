require "common"

function psr_all_bits_set()
        r8 = target.read_reg(8)
        if r8 ~= 0xf then
                print('PSR bits unset')
                return -1
        end
end

function psr_zero_set()
        r8 = target.read_reg(8)
        if bit32.band(r8, 0x1) ~= 0x1 then
                print(string.format('Z flag not set when expected %08x', r8))
                return -1
        end
end

return run_test({
	elf = "psr",
	max_cycle_count = 1000,
	modes = {"step", "run"},
        testpoints = {
                { TP_USER, 0, psr_all_bits_set },
                { TP_USER, 1, psr_zero_set },
                { TP_SUCCESS, 0 }
        }
})
