-- Timer test, verify that when enabled the timer decrements and doesn't
-- change when disabled.
require "common"

count0 = 0
count1 = 0
count2 = 0
count3 = 0

function read_count0()
	count0 = target.read_reg(2)
	print(count0)
end

function read_count1()
	count1 = target.read_reg(2)
	print(count1)
end

function read_count2()
	count2 = target.read_reg(2)
end

function read_count3()
	count3 = target.read_reg(2)
end

function validate()
	print(count0)
	print(count1)
	print(count2)
	print(count3)
	if not (count2 < count1 and count1 < count0 and count3 == count2) then
		return -1
	end
end

return run_test({
	elf = "timer",
	max_cycle_count = 1000,
	-- Only run in single step mode 
	modes = {"run"},
	testpoints = {
		{ TP_USER, 0, read_count0 },
		{ TP_USER, 1, read_count1 },
		{ TP_USER, 2, read_count2 },
		{ TP_USER, 3, read_count3 },
		{ TP_SUCCESS, 0, validate },
	}
})
