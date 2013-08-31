module keynsham_bootrom(input wire		clk,
			input wire [6:0]	i_addr,
			output wire [31:0]	i_data,
			input wire		d_access,
			input wire		d_cs,
			input wire [6:0]	d_addr,
			input wire [3:0]	d_bytesel,
			output wire [31:0]	d_data,
			output wire		d_ack);

`ifdef __ICARUS__

sim_dp_rom	mem(.clk(clk),
		    .i_addr(i_addr[6:0]),
		    .i_data(i_data),
		    .d_access(d_access),
		    .d_cs(d_cs),
		    .d_addr(d_addr[6:0]),
		    .d_data(d_data),
		    .d_bytesel(d_bytesel),
		    .d_ack(d_ack));
`else /* Altera FPGA */

reg		rom_ack = 1'b0;

assign		d_ack = rom_ack;

bootrom		mem(.clock(clk),
		    .address_a(i_addr[6:0]),
		    .q_a(i_data),
		    .address_b(d_addr[6:0]),
		    .q_b(d_data));

always @(posedge clk)
	rom_ack <= d_access && d_cs;

`endif /* __ICARUS__ */

endmodule
