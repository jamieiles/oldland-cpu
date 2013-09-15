step = target.step
stop = target.stop
run = target.run
write_reg = target.write_reg
write32 = target.write32
write16 = target.write16
write8 = target.write8
loadelf = target.loadelf
connect = target.connect
reset = target.reset

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

function target_read_string(addr)
	str = ""

	repeat
		v = target.read8(ptr)
		if v ~= 0 then
			str = str .. string.format("%c", v)
		end

		ptr = ptr + 1
	until v == 0

	return str
end

function get_buildid()
	ptr = 0x10000000 + target.read32(0x10000004)

	return target_read_string(ptr)
end

function get_build_date()
	ptr = 0x10000000 + target.read32(0x10000008)

	return target_read_string(ptr)
end

function report_cpu()
	print("BuildID:\t" .. get_buildid())
	print("BuildDate:\t" .. get_build_date())
end
