require "common"

MAX_CYCLE_COUNT = 128

connect("localhost", "36000")
loadelf("badaddr")

tp = run_to_tp()
if not tp or tp.type ~= TP_SUCCESS then
	print(string.format("unexpected testpoint at %08x", target.read_reg(16)))
	return -1
end
