require "common"

connect_test_target()
target.reset()
loadelf("step")

if target.read_reg(16) ~= 0x0 then
	print('PC reset to unexpected address')
	return -1
end

target.step()

if target.read_reg(16) ~= 0x4 then
	print('stepped to unexpected address')
	return -1
end

target.run()
if target.read_reg(16) ~= 0xc then
	print('ran to unexpected address')
	return -1
end
target.read32(0x0)
if target.read_reg(16) ~= 0xc then
	print('memory read advanced PC')
	return -1
end

return 0
