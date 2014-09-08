require "common"

function validate_tx()
	expected_tx = {
		0xaa,
		0x55,
		0x55,
		0xaa
	}

	for i, v in ipairs(expected_tx) do
		txdata = target.read8(0x80004000 + 8192 + i - 1)
		if txdata ~= v then
			print(string.format("unexpected tx data %x at offs %x", txdata, i - 1))
			--return -1
		end
	end
end

function validate_rx()
	expected_rx = {
		0x55,
		0xaa,
		0xaa,
		0x55
	}

	for i, v in ipairs(expected_rx) do
		rxdata = target.read8(0x80004000 + 8192 + i - 1)
		if rxdata ~= v then
			print(string.format("unexpected rx data %x", rxdata))
			return -1
		end
	end
end

return run_test({
	elf = "spiloopback",
	max_cycle_count = 1000,
	modes = {"step", "run"},
	testpoints = {
		{ TP_USER, 0, validate_tx },
		{ TP_SUCCESS, 0, validate_rx },
	}
})
