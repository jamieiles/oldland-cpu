require "common"

function assert_tlb_disabled()
        psr = target.read_cr(1)

        if bit32.band(psr, 0x80) ~= 0x00 then
                print('mmu enabled during miss handler')
                return -1
        end
end

function validate_r1()
	r1 = target.read_reg(1)
	if r1 ~= 0x0bad1dea then
		print(string.format("r1 %08x !=  %08x", r1, 0x0bad1dea))
		return -1
	end
end

return run_test({
	elf = "tlb",
	max_cycle_count = 128,
	modes = {"step", "run"},
	testpoints = {
		{ TP_USER, 0 },
		{ TP_USER, 1, assert_tlb_disabled },
		{ TP_USER, 2, validate_r1 },
		{ TP_USER, 3, assert_tlb_disabled },
		{ TP_USER, 4 },
		{ TP_SUCCESS, 0 },
	}
})
