module dc_ram(input wire			clk_a,
	      input wire [addr_bits - 1:0]	addr_a,
	      input wire [data_bits - 1:0]	din_a,
	      output reg [data_bits - 1:0]	dout_a,
	      input wire			wr_en_a,
	      input wire			clk_b,
	      input wire [addr_bits - 1:0]	addr_b,
	      input wire [data_bits - 1:0]	din_b,
	      output reg [data_bits - 1:0]	dout_b,
	      input wire			wr_en_b);

parameter addr_bits = 32;
parameter data_bits = 32;

// The RAM is driven by two clocks for synchronization between clock domains,
// but in use only one domain will write at a time.
// verilator lint_save
// verilator lint_off MULTIDRIVEN

reg [data_bits - 1:0] ram[2 ** addr_bits - 1:0] /*synthesis syn_ramstyle = "no_rw_check"*/;

integer i;

initial begin
	for (i = 0; i < 2 ** addr_bits; i = i + 1)
		ram[i] = {data_bits{1'b0}};
end

always @(posedge clk_a) begin
	if (wr_en_a)
		ram[addr_a] <= din_a;
	dout_a <= ram[addr_a];
end

always @(posedge clk_b) begin
	if (wr_en_b)
		ram[addr_b] <= din_b;
	dout_b <= ram[addr_b];
end

// verilator lint_restore

endmodule
