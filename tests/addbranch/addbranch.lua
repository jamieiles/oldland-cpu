-- Perform some additions and branches close together making sure that result
-- forwarding works as expected.
require "bit32"

CYCLE_LIMIT = 100
BINARY = "addbranch.bin"

function run()
	run_cpu()
end
