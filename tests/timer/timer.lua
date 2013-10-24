-- Timer test, verify that when enabled the timer decrements and doesn't
-- change when disabled.
require "common"

MAX_CYCLE_COUNT = 1024

connect_and_load("timer")

count0 = 0
count1 = 0
count2 = 0
count3 = 0

function read_count0()
	count0 = target.read_reg(2)
end

function read_count1()
	count1 = target.read_reg(2)
end

function read_count2()
	count2 = target.read_reg(2)
end

function read_count3()
	count3 = target.read_reg(2)
end

expect_testpoints = {
	{ TP_USER, 0, read_count0 },
	{ TP_USER, 1, read_count1 },
	{ TP_USER, 2, read_count2 },
	{ TP_USER, 3, read_count3 },
	{ TP_SUCCESS, 0 },
}

rc = run_testpoints(expect_testpoints)
if (rc ~= 0) then
	return rc
end
return count2 < count1 and count1 < count0 and count3 == count2
