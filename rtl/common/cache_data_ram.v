module cache_data_ram(input wire			clk,
		      input wire [addr_bits - 1:0]	read_addr,
		      output wire [31:0]		read_data,
		      input wire			wr_en,
		      input wire [addr_bits - 1:0]	write_addr,
		      input wire [31:0]			write_data,
		      input wire [3:0]			bytesel);

parameter nr_entries = 32;

localparam addr_bits = $clog2(nr_entries);

genvar		m;

wire [7:0] q [3:0];

generate
for (m = 0; m < 4; m = m + 1) begin: cache_ram
	block_ram	#(.data_bits(8),
			  .nr_entries(nr_entries))
			bram(.clk(clk),
			     .read_addr(read_addr),
			     .read_data(q[m]),
			     .wr_en(bytesel[m] && wr_en),
			     .write_addr(write_addr),
			     .write_data(write_data[((m + 1) * 8) - 1:m * 8]));
end
endgenerate

assign read_data = {q[3], q[2], q[1], q[0]};

endmodule
