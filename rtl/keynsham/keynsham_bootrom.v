module keynsham_bootrom(input wire clk,
			input wire [31:0] i_addr,
			output wire [31:0] i_data,
			input wire d_access,
			input wire d_cs,
			input wire [31:0] d_addr,
			input wire [3:0] d_bytesel,
			output wire [31:0] d_data,
			output wire d_ack);

`ifdef __ICARUS__

sim_dp_rom	mem(.clk(clk),
		    .i_addr(i_addr[11:0]),
		    .i_data(i_data),
		    .d_access(d_access),
		    .d_cs(d_cs),
		    .d_addr({d_addr[11:2], 2'b0}),
		    .d_data(d_data),
		    .d_bytesel(d_bytesel),
		    .d_ack(d_ack));
`else /* Altera FPGA */

bootrom		mem(.clock(clk),
		    .address_a(i_addr[11:2]), /* Word addressed with byte enables. */
		    .q_a(i_data),
		    .address_b(d_addr[11:2]), /* Word addressed with byte enables. */
		    .q_b(d_data));

reg rom_ack = 1'b0;

always @(posedge clk)
	rom_ack <= d_access && d_cs;
assign d_ack = rom_ack;

`endif /* __ICARUS__ */

endmodule
