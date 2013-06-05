module keynsham_sdram(input wire clk,
		      input wire bus_access,
		      input wire sdram_cs,
		      input wire ctrl_cs,
		      input wire [31:0] bus_addr,
		      input wire [31:0] bus_wr_val,
		      input wire bus_wr_en,
		      input wire [3:0] bus_bytesel,
		      output reg bus_error,
		      output wire bus_ack,
		      output wire [31:0] bus_data,
		      output wire s_ras_n,
		      output wire s_cas_n,
		      output wire s_wr_en,
		      output wire [1:0] s_bytesel,
		      output wire [12:0] s_addr,
		      output wire s_cs_n,
		      output wire s_clken,
		      inout [15:0] s_data,
		      output wire [1:0] s_banksel);

wire [31:0] bridge_addr;
wire [15:0] bridge_wdata;
wire [15:0] bridge_rdata;
wire bridge_wr_en;
wire [1:0] bridge_bytesel;
wire bridge_compl;

wire sdram_ack;
wire [31:0] sdram_data;

wire config_done;
reg ctrl_ack = 1'b0;
reg [31:0] ctrl_data = 32'b0;

assign bus_ack = sdram_ack | ctrl_ack;
assign bus_data = sdram_cs ? sdram_data : ctrl_data;

initial begin
	bus_error = 1'b0;
end

bridge_32_16		br(.clk(clk),
			   .h_cs(bus_access & sdram_cs),
			   .h_addr(bus_addr),
			   .h_wdata(bus_wr_val),
			   .h_rdata(sdram_data),
			   .h_wr_en(bus_wr_en),
			   .h_bytesel(bus_bytesel),
			   .h_compl(sdram_ack),
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

always @(posedge clk) begin
	if (ctrl_cs && bus_access && !bus_wr_en)
		ctrl_data <= {31'b0, config_done};
	ctrl_ack <= bus_access && ctrl_cs;
end

endmodule
