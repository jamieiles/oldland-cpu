require "bit32"

CYCLE_LIMIT = 1000
BINARY = "hello.bin"

uart_data = ""

function data_write_hook(addr, width, value)
	if addr == 0x80000000 and width == 32 then
		uart_data = uart_data .. string.format("%c", bit32.band(value, 0xff))
	end
end

function run()
	run_cpu()
end

function validate_result()
	if uart_data ~= "Hello, world!" then
		sim.err("output string does not match - \"" .. uart_data .. "\"")
	end
end
