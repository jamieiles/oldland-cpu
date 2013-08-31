TP_SUCCESS	= 1
TP_FAILURE	= 2
TP_USER		= 4

function get_testpoint(pc)
	return testpoints[pc]
end

cycle_count = 0

function run_to_tp()
	while true do
		target.step()
		cycle_count = cycle_count + 1
		if _G['MAX_CYCLE_COUNT'] and cycle_count > MAX_CYCLE_COUNT then
			break
		end

		pc = target.read_reg(16)
		tp = get_testpoint(pc)

		if tp then
			return tp
		end
	end
end
