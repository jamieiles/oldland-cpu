function step()
	target.step()
end

function stop()
	target.stop()
end

function run()
	target.run()
end

function read_reg(reg)
	v = target.read_reg(reg)
	print(string.format("%08x", v))
end

regnames = { 'r0', 'r1', 'r2', 'r3', 'r4', 'r5', 'sp', 'lr', 'pc' }

function regs()
	for idx, name in ipairs(regnames) do
		v = target.read_reg(idx - 1)
		print(string.format("%03s: %08x", name, v))
	end
end
