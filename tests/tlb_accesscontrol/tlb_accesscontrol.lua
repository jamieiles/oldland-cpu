require "common"

function validate_no_mmu_access()
	r7 = target.read_reg(7)
	if r7 ~= 0xdeadbeef then
		print(string.format("unexpected nommu access %08x != 0xdeadbeef", r7))
		return -1
	end
end

return run_test({
	elf = "tlb_accesscontrol",
	max_cycle_count = 256,
	modes = {"run", "step"},
	testpoints = {
		{ TP_USER, 0, validate_no_mmu_access },
		-- No perms read
		{ TP_USER, 0x100 }, -- Fault
		{ TP_USER, 1 },
		-- No perms write
		{ TP_USER, 0x100 }, -- Fault
		{ TP_USER, 2 },
		-- Switch to read only
		{ TP_USER, 3 }, -- Succesful read
		{ TP_USER, 0x100 }, -- Faulted write
		{ TP_USER, 4 },
		-- Switch to write only
		{ TP_USER, 0x100 }, -- Faulted read
		{ TP_USER, 5 },
		{ TP_USER, 6 }, -- Successful write
		-- Execute non-executable page
		{ TP_USER, 0x200 }, -- Ifetch abort
		{ TP_USER, 7 },
		-- Mark as executable and retry
		{ TP_USER, 0x300 }, -- Sucessful call
		{ TP_USER, 8 },

		-- Done
		{ TP_SUCCESS, 0 },
	}
})
