module keynsham_sdram(input wire		clk,
		      /* Data bus. */
		      input wire		ctrl_cs,
		      input wire		d_access,
		      input wire		d_cs,
		      input wire [29:0] 	d_addr,
		      input wire [31:0] 	d_wr_val,
		      input wire		d_wr_en,
		      input wire [3:0]		d_bytesel,
		      output reg		d_error,
		      output wire		d_ack,
		      output wire [31:0]	d_data,
		      /* Instruction bus. */
		      input wire		i_access,
		      input wire		i_cs,
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

wire [30:0]	bridge_addr;
wire [15:0]	bridge_wdata;
wire [15:0]	bridge_rdata;
wire		bridge_wr_en;
wire [1:0]	bridge_bytesel;
wire		bridge_compl;

wire		sdram_ack;

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

assign		d_ack = ctrl_ack | (d_active ? q_ack : 1'b0);
assign		i_ack = !d_active ? q_ack : 1'b0;
assign		d_data = d_cs ? q_data : ctrl_data;
assign		i_data = q_data;

bridge_32_16		br(.clk(clk),
			   .h_cs(q_cs),
			   .h_addr(q_addr),
			   .h_wdata(q_wr_val),
			   .h_rdata(q_data),
			   .h_wr_en(q_wr_en),
			   .h_bytesel(q_bytesel),
			   .h_compl(q_ack),
			   .b_addr(bridge_addr),
			   .b_wdata(bridge_wdata),
			   .b_rdata(bridge_rdata),
			   .b_wr_en(bridge_wr_en),
			   .b_bytesel(bridge_bytesel),
			   .b_compl(bridge_compl));

sdram_controller	sdram(.clk(clk),
			      .h_addr(bridge_addr),
			      .h_wr_en(bridge_wr_en),
			      .h_bytesel(bridge_bytesel),
			      .h_compl(bridge_compl),
			      .h_wdata(bridge_wdata),
			      .h_rdata(bridge_rdata),
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
