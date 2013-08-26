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
	print(string.format("%08x", target.read_reg(reg)))
end

function write_reg(reg, val)
	target.write_reg(reg, val)
end

function read32(addr)
	print(string.format("%08x", target.read32(addr)))
end

function write32(addr, val)
	target.write32(addr, val)
end

function read16(addr)
	print(string.format("%04x", target.read16(addr)))
end

function write16(addr, val)
	target.write16(addr, val)
end

function read8(addr)
	print(string.format("%02x", target.read8(addr)))
end

function write8(addr, val)
	target.write8(addr, val)
end

function loadelf(path)
	target.loadelf(path)
end

regnames = { 'r0', 'r1', 'r2', 'r3', 'r4', 'r5', 'sp', 'lr', 'pc' }

function regs()
	for idx, name in ipairs(regnames) do
		v = target.read_reg(idx - 1)
		print(string.format("%03s: %08x", name, v))
	end
end
