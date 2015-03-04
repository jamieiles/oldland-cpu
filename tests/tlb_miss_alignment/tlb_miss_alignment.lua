require "common"

function validate_r8()
	r8 = target.read_reg(8)

	if r8 ~= 6 then
		print(string.format("%08x != 6", r8))
		return -1
	end
end

return run_test({
	elf = "tlb_miss_alignment",
	max_cycle_count = 128,
	modes = {"step", "run"},
	testpoints = {
		{ TP_USER, 0, validate_r8 },
		{ TP_SUCCESS, 0 },
	}
})
