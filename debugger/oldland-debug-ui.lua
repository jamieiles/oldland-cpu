require "bit32"
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

function read_cpuid(reg)
	print(string.format("%08x", target.read_cpuid(reg)))
end

function regs()
	print(string.format(" PSR: %08x", target.read_cr(1)))
	print(string.format("SPSR: %08x", target.read_cr(2)))
	print(string.format(" FAR: %08x", target.read_cr(3)))
	print(string.format("DFAR: %08x", target.read_cr(4)))
	print(string.format("  r0: %08x %08x %08x %08x", target.read_reg(0),
			    target.read_reg(1), target.read_reg(2),
			    target.read_reg(3)))
	print(string.format("  r4: %08x %08x %08x %08x", target.read_reg(4),
			    target.read_reg(5), target.read_reg(6),
			    target.read_reg(7)))
	print(string.format("  r8: %08x %08x %08x %08x", target.read_reg(8),
			    target.read_reg(9), target.read_reg(10),
			    target.read_reg(11)))
	print(string.format(" r12: %08x", target.read_reg(12)))
	print(string.format("  fp: %08x sp: %08x lr: %08x",
			    target.read_reg(13), target.read_reg(14),
			    target.read_reg(15)))
	print(string.format("  pc: %08x", target.read_reg(16)))
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

function cpuid()
	version = target.read_cpuid(0)

	vendor = bit32.rshift(version, 16)
	model = bit32.band(version, 0xffff)

	print(string.format("Vendor:\t0x%04x", vendor))
	print(string.format("Model:\t0x%04x", model))
	print(string.format("Hz:\t%u", target.read_cpuid(1)))
	print("Instruction Cache:")
	icache = target.read_cpuid(3)
	line_size = bit32.band(icache, 0xff) * 4
        num_ways = bit32.rshift(icache, 24)
	size = bit32.band(bit32.rshift(icache, 8), 0xffff) * line_size
	print(string.format("  Size: %uKB", size / 1024))
	print(string.format("  Line: %u", line_size))
	print(string.format("  Ways: %u", num_ways))
	print("Data Cache:")
	dcache = target.read_cpuid(4)
	line_size = bit32.band(dcache, 0xff) * 4
	size = bit32.band(bit32.rshift(dcache, 8), 0xffff) * line_size
        num_ways = bit32.rshift(dcache, 24)
	print(string.format("  Size: %uKB", size / 1024))
	print(string.format("  Line: %u", line_size))
	print(string.format("  Ways: %u", num_ways))
end

function pairsByKeys (t, f)
	local a = {}
	for n in pairs(t) do
		table.insert(a, n)
	end
	table.sort(a, f)
	local i = 0
	local iter = function()
		i = i + 1
		if a[i] == nil then
			return nil
		else
			return a[i], t[a[i]]
		end
	end
	return iter
end

function lookup_sym_from_address(search_address)
	local inverse_symtab = {}

	for k, v in pairs(syms) do
		inverse_symtab[v] = k
	end

	local sym = "??"

	for addr, name in pairsByKeys(inverse_symtab) do
		if addr > search_address then
			break
		end
		sym = name
	end

	return sym
end

function print_bt_sym(index, name, value)
	print(string.format("  #%d %s <%08x>", index, name, value))
end

function backtrace(limit)
	local fp = target.read_reg(14)

	if limit == nil then
		limit = 64
	end

	print_bt_sym(0, lookup_sym_from_address(target.read_reg(16)), target.read_reg(16))
	local i = 0
	while bit32.band(fp, 0x1) ~= 0x1 and i < limit do
		prev_fp = target.read32(fp)
		prev_lr = target.read32(fp + 4)
		print_bt_sym(i + 1, lookup_sym_from_address(prev_lr), prev_lr)
		fp = prev_fp
		i = i + 1
	end
end
