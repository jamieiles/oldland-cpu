module keynsham_ram(input wire		clk,
		    /* Instruction bus. */
		    input wire		i_access,
		    input wire		i_cs,
		    input wire [10:0]	i_addr,
		    output wire [31:0]	i_data,
		    output wire		i_ack,
		    /* Data bus. */
		    input wire		d_access,
		    input wire		d_cs,
		    input wire [10:0]	d_addr,
		    input wire [3:0]	d_bytesel,
		    input wire [31:0]	d_wr_val,
		    input wire		d_wr_en,
		    output wire [31:0]	d_data,
		    output wire		d_ack);

`ifdef __ICARUS__

sim_dp_ram	mem(.clk(clk),
		    .i_access(i_access),
		    .i_cs(i_cs),
		    .i_addr(i_addr[10:0]),
		    .i_data(i_data),
		    .i_ack(i_ack),
		    .d_access(d_access),
		    .d_cs(d_cs),
		    .d_addr(d_addr[10:0]),
		    .d_data(d_data),
		    .d_bytesel(d_bytesel),
		    .d_wr_val(d_wr_val),
		    .d_wr_en(d_wr_en),
		    .d_ack(d_ack));
`else /* Altera FPGA */

reg		d_ram_ack = 1'b0;
assign		d_ack = d_ram_ack;

reg		i_ram_ack = 1'b0;
assign		i_ack = i_ram_ack;

ram		mem(.clock(clk),
		    .address_a(i_addr[9:0]), /* Word addressed with byte enables. */
		    .data_a(32'b0),
		    .byteena_a(d_bytesel),
		    .wren_a(1'b0),
		    .q_a(i_data),
		    .address_b(d_addr[9:0]), /* Word addressed with byte enables. */
		    .data_b(d_wr_val),
		    .byteena_b(d_bytesel),
		    .wren_b(d_wr_en & d_cs),
		    .q_b(d_data));

always @(posedge clk)
	d_ram_ack <= d_access && d_cs;

always @(posedge clk)
	i_ram_ack <= i_access && i_cs;

`endif /* __ICARUS__ */

endmodule
