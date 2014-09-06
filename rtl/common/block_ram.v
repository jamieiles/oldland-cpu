module block_ram(input wire			clk,
		 input wire [addr_bits - 1:0]	read_addr,
		 output wire [data_bits - 1:0]	read_data,
		 input wire			wr_en,
		 input wire [addr_bits - 1:0]	write_addr,
		 input wire [data_bits - 1:0]	write_data);

parameter data_bits = 8;
parameter nr_entries = 32;

localparam addr_bits = $clog2(nr_entries);

reg [data_bits - 1:0]	mem[nr_entries - 1:0];
reg [data_bits - 1:0] 	q = {data_bits{1'b0}};
reg [data_bits - 1:0] 	bypass_data = {data_bits{1'b0}};
reg			bypass = 1'b0;

integer i;

initial begin
	for (i = 0; i < nr_entries; i = i + 1)
		mem[i] = {data_bits{1'b0}};
end

always @(posedge clk) begin
	if (wr_en)
		mem[write_addr] <= write_data;

	q <= mem[read_addr];
	bypass <= wr_en && read_addr == write_addr;
	bypass_data <= write_data;
end

assign read_data = bypass ? bypass_data : q;

endmodule
