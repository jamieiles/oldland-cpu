require "math"
require "io"

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

target.read_cr = function(reg)
	return target.read_reg(32 + reg)
end

function read_cr(reg)
	print(string.format("%08x", target.read_cr(reg)))
end

function write_cr(reg, val)
	return target.write_reg(32 + reg, val)
end
target.write_cr = write_cr

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

function dump_mem(start, len)
	count = 0

	while count < len do
		row = {}
		for col = 1, math.min(len - count, 16) do
			row[col] = target.read8(start + count + col - 1)
		end

		for i, v in ipairs(row) do
			io.write(string.format("%02x ", v))
		end

		for i = math.min(len - count, 16), 16 do
			io.write("   ")
		end

		io.write("|")
		repr = ""
		for i, v in ipairs(row) do
			if v < 0x20 or v > 0x7e then
				v = 0x2e
			end
			repr = repr .. string.format("%c", v)
		end
		io.write(string.format("%s", repr))
		io.write("|")
		io.write("\n")

		count = count + math.min(len - count, 16)
	end
end
