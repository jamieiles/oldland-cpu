module keynsham_bootrom(input wire		clk,
			/* Instruction bus. */
			input wire		i_access,
			input wire		i_cs,
			input wire [6:0]	i_addr,
			output wire [31:0]	i_data,
			output wire		i_ack,
			/* Data bus. */
			input wire		d_access,
			input wire		d_cs,
			input wire [6:0]	d_addr,
			input wire [3:0]	d_bytesel,
			output wire [31:0]	d_data,
			output wire		d_ack);

wire [31:0]	_d_data;
wire [31:0]	_i_data;

assign		d_data = d_ack ? _d_data : 32'b0;
assign		i_data = i_ack ? _i_data : 32'b0;

`ifdef __ICARUS__

sim_dp_rom	mem(.clk(clk),
		    .i_access(i_access),
		    .i_cs(i_cs),
		    .i_addr(i_addr[6:0]),
		    .i_data(_i_data),
		    .i_ack(i_ack),
		    .d_access(d_access),
		    .d_cs(d_cs),
		    .d_addr(d_addr[6:0]),
		    .d_data(_d_data),
		    .d_bytesel(d_bytesel),
		    .d_ack(d_ack));
`else /* Altera FPGA */

reg		rom_d_ack = 1'b0;
assign		d_ack = rom_d_ack;

reg		rom_i_ack = 1'b0;
assign		i_ack = rom_i_ack;

bootrom		mem(.clock(clk),
		    .address_a(i_addr[6:0]),
		    .q_a(_i_data),
		    .address_b(d_addr[6:0]),
		    .q_b(_d_data));

always @(posedge clk)
	rom_d_ack <= d_access && d_cs;

always @(posedge clk)
	rom_i_ack <= i_access && i_cs;

`endif /* __ICARUS__ */

endmodule
