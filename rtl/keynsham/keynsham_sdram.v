`ifdef verilator
`define CONFIG_CONTROLLER verilator_sdram_model
`else
`define CONFIG_CONTROLLER sdram_controller
`endif

module keynsham_sdram(input wire		clk,
		      /* Data bus. */
		      output wire		ctrl_cs,
		      input wire		d_access,
		      output wire		d_cs,
		      input wire [29:0] 	d_addr,
		      input wire [31:0] 	d_wr_val,
		      input wire		d_wr_en,
		      input wire [3:0]		d_bytesel,
		      output reg		d_error,
		      output wire		d_ack,
		      output wire [31:0]	d_data,
		      /* Instruction bus. */
		      input wire		i_access,
		      output wire		i_cs,
		      input wire [29:0] 	i_addr,
		      output reg		i_error,
		      output wire		i_ack,
		      output wire [31:0]	i_data,
		      /* SDRAM signals. */
		      output wire		s_ras_n,
		      output wire		s_cas_n,
		      output wire		s_wr_en,
		      output wire [1:0]		s_bytesel,
		      output wire [12:0]	s_addr,
		      output wire		s_cs_n,
		      output wire		s_clken,
		      inout [15:0]		s_data,
		      output wire [1:0]		s_banksel);

parameter	clkf = 50000000;
parameter	bus_address = 32'h0;
parameter	bus_size = 32'h0;
parameter	ctrl_bus_address = 32'h0;
parameter	ctrl_bus_size = 32'h0;

wire		config_done;
reg		ctrl_ack = 1'b0;
reg [31:0]	ctrl_data = 32'b0;

/* Data accesses have higher priority than instructions to prevent deadlock. */
wire		d_start = d_access & d_cs;
reg		d_in_progress = 1'b0;
wire		d_active = d_start | d_in_progress;

wire		q_cs = d_active ? d_access & d_cs : i_access & i_cs;
wire [29:0]	q_addr = d_active ? d_addr : i_addr;
wire [31:0]	q_wr_val = d_wr_val; /* No writes from instruction bus. */
wire [31:0]	q_data;
wire		q_wr_en = d_active ? d_wr_en : 1'b0;
wire [3:0]	q_bytesel = d_active ? d_bytesel : 4'b1111;
wire		q_ack;

assign		d_ack = ctrl_ack | q_ack;
assign		i_ack = !d_active ? q_ack : 1'b0;
wire [31:0]	data = d_cs ? q_data : ctrl_data;
assign		i_data = q_ack ? q_data : 32'b0;

assign		d_data = q_ack | ctrl_ack ? data : 32'b0;

cs_gen		#(.address(bus_address), .size(bus_size))
		d_cs_gen(.bus_addr(d_addr), .cs(d_cs));
cs_gen		#(.address(bus_address), .size(bus_size))
		i_cs_gen(.bus_addr(i_addr), .cs(i_cs));
cs_gen		#(.address(ctrl_bus_address), .size(ctrl_bus_size))
		ctrl_cs_gen(.bus_addr(d_addr), .cs(ctrl_cs));

`CONFIG_CONTROLLER	#(.clkf(clkf))
			sdram(.clk(clk),
			      .cs(q_cs),
			      .h_addr(q_addr),
			      .h_wr_en(q_wr_en),
			      .h_bytesel(q_bytesel),
			      .h_compl(q_ack),
			      .h_wdata(q_wr_val),
			      .h_rdata(q_data),
			      .h_config_done(config_done),
			      .s_ras_n(s_ras_n),
			      .s_cas_n(s_cas_n),
			      .s_wr_en(s_wr_en),
			      .s_bytesel(s_bytesel),
			      .s_addr(s_addr),
			      .s_cs_n(s_cs_n),
			      .s_clken(s_clken),
			      .s_data(s_data),
			      .s_banksel(s_banksel));

initial begin
	d_error = 1'b0;
	i_error = 1'b0;
end

always @(posedge clk) begin
	if (ctrl_cs && d_access && !d_wr_en)
		ctrl_data <= {31'b0, config_done};
	ctrl_ack <= d_access && ctrl_cs;
end

always @(posedge clk)
	if (d_start)
		d_in_progress <= 1'b1;
	else if (d_in_progress && q_ack)
		d_in_progress <= 1'b0;

endmodule
