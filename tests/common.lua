TP_SUCCESS	= 1
TP_FAILURE	= 2
TP_USER		= 4

function get_testpoint(pc)
	return testpoints[pc]
end

cycle_count = 0

function step_to_tp(max_cycle_count)
	while true do
		target.step()
		cycle_count = cycle_count + 1
		if max_cycle_count and cycle_count > max_cycle_count then
                        print("Maximum cycle count exceeded")
			break
		end
		read_reg(16)

		pc = target.read_reg(16)
		tp = get_testpoint(pc)

		if tp then
			return tp
		end
	end
end

function run_to_tp()
	while true do
		target.run()
		pc = target.read_reg(16)
		tp = get_testpoint(pc)

		if tp then
			return tp
		end
	end
end

function tp_type(typ)
        if tp.type == TP_SUCCESS then return "SUCCESS" end
        if tp.type == TP_FAILURE then return "FAILURE" end
        if tp.type == TP_USER then return "USER" end
        return "???"
end

function step_testpoints(expected_testpoints, max_cycle_count)
	for _, v in pairs(expected_testpoints) do
		tp = step_to_tp(max_cycle_count)
		if not tp or
		tp.type ~= v[1] or
		tp.tag ~= v[2] then
                        if tp then
                                print(string.format("unexpected testpoint %s:%u at %08x",
                                                    tp_type(tp.type), tp.tag,
                                                    target.read_reg(16)))
                        else
                                print("No testpoint hit")
                        end
			return -1
		end

                print(string.format("hit tp %s:%u", tp_type(tp.type), tp.tag))

                if v[3] and v[3]() then return -1 end

		-- Advance the PC to the instruction after the breakpoint.
		target.write_reg(16, target.read_reg(16) + 4)
	end

	return 0
end

function run_testpoints(expected_testpoints)
	for _, v in pairs(expected_testpoints) do
		tp = run_to_tp()
		if not tp or
		tp.type ~= v[1] or
		tp.tag ~= v[2] then
                        if tp then
                                print(string.format("unexpected testpoint %s:%u at %08x",
                                                    tp_type(tp.type), tp.tag,
                                                    target.read_reg(16)))
                        else
                                print("No testpoint hit")
                        end
			return -1
		end

                print(string.format("hit tp %s:%u", tp_type(tp.type), tp.tag))

                if v[3] and v[3]() then return -1 end

		-- Advance the PC to the instruction after the breakpoint.
		target.write_reg(16, target.read_reg(16) + 4)
	end

	return 0
end

function connect_test_target()
	host = "localhost"
	port = 36000

	host_override = os.getenv("OLDLAND_TARGET")
	if host_override then
		host = nil
		port = nil
		for i in string.gmatch(host_override,  "[^:]+") do
			if not host then host = i
			elseif not port then port = i end
		end
	end

	target.connect(host, port)
end

function run_test(test)
	connect_test_target()

	if test.testpoints == nil then
		test.testpoints = { {TP_SUCCESS, 0} }
	end

	for _, mode in pairs(test.modes) do
		target.reset()
		loadelf(test.elf)

		if test.setup then
			test.setup()
		end

		handlers = {
			["step"] = step_testpoints,
			["run"] = run_testpoints,
		}
		rc = handlers[mode](test.testpoints, test.max_cycle_count)
		if rc and rc ~= 0 then
			return rc
		end
	end

	return 0
end
