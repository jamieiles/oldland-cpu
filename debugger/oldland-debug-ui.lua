step = target.step
stop = target.stop
run = target.run
write_reg = target.write_reg
write32 = target.write32
write16 = target.write16
write8 = target.write8
loadelf = target.loadelf

function read_reg(reg)
	print(string.format("%08x", target.read_reg(reg)))
end

function read32(addr)
	print(string.format("%08x", target.read32(addr)))
end

function read16(addr)
	print(string.format("%04x", target.read16(addr)))
end

function read8(addr)
	print(string.format("%02x", target.read8(addr)))
end

regnames = { 'r0', 'r1', 'r2', 'r3', 'r4', 'r5', 'r6', 'r7',
	     'r8', 'r9', 'r10', 'r11', 'r12', 'fp', 'sp', 'lr', 'pc' }

function regs()
	for idx, name in ipairs(regnames) do
		v = target.read_reg(idx - 1)
		print(string.format("%03s: %08x", name, v))
	end
end
