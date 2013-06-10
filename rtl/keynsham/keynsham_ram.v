module keynsham_ram(input wire clk,
		    input wire [31:0] i_addr,
		    output wire [31:0] i_data,
		    input wire d_access,
		    input wire d_cs,
		    input wire [31:0] d_addr,
		    input wire [3:0] d_bytesel,
		    input wire [31:0] d_wr_val,
		    input wire d_wr_en,
		    output wire [31:0] d_data,
		    output wire d_ack);

`ifdef __ICARUS__

sim_dp_ram	mem(.clk(clk),
		    .i_addr({20'b0, i_addr[11:2], 2'b0}),
		    .i_data(i_data),
		    .d_access(d_access),
		    .d_cs(d_cs),
		    .d_addr({20'b0, d_addr[11:2], 2'b0}),
		    .d_data(d_data),
		    .d_bytesel(d_bytesel),
		    .d_wr_val(d_wr_val),
		    .d_wr_en(d_wr_en),
		    .d_ack(d_ack));
`else /* Altera FPGA */

ram		mem(.clock(clk),
		    .address_a(i_addr[11:2]), /* Word addressed with byte enables. */
		    .data_a(32'b0),
		    .byteena_a(4'b1111),
		    .wren_a(0),
		    .q_a(i_data),
		    .address_b(d_addr[11:2]), /* Word addressed with byte enables. */
		    .data_b(d_wr_val),
		    .byteena_b(d_bytesel),
		    .wren_b(d_wr_en & d_cs),
		    .q_b(d_data));

reg ram_ack = 1'b0;

always @(posedge clk)
	ram_ack <= d_access && d_cs;
assign d_ack = ram_ack;

`endif /* __ICARUS__ */

endmodule
