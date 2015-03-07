require "common"

function assert_user_mode()
	cr1 = target.read_cr(1)
	if bit32.band(cr1, 0x100) ~= 0x100 then
		print("in supervisor mode when user mode expected")
		return -1
	end
end

function assert_supervisor_mode()
	cr1 = target.read_cr(1)
	if bit32.band(cr1, 0x100) == 0x100 then
		print("in user mode when supervisor mode expected")
		return -1
	end
end

return run_test({
	elf = "exceptions_user",
	max_cycle_count = 128,
	modes = {"step", "run"},
	testpoints = {
		-- SWI enters supervisor mode, RFE returns to user.
		{ TP_USER, 0, assert_user_mode },
		{ TP_USER, 0x100, assert_supervisor_mode },
		{ TP_USER, 1, assert_user_mode },
		-- Data abort
		{ TP_USER, 0x200, assert_supervisor_mode },
		{ TP_USER, 2, assert_user_mode },
		-- Illegal instruction
		{ TP_USER, 0x300, assert_supervisor_mode },
		{ TP_USER, 3, assert_user_mode },
		-- Ifetch abort
		{ TP_USER, 0x400, assert_supervisor_mode },
		{ TP_USER, 4, assert_user_mode },

		{ TP_SUCCESS, 0 },
	}
})
