module keynsham_sdram(input wire clk,
		      input wire bus_access,
		      input wire bus_cs,
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

initial begin
	bus_error = 1'b0;
end

bridge_32_16		br(.clk(clk),
			   .h_cs(bus_access & bus_cs),
			   .h_addr(bus_addr),
			   .h_wdata(bus_wr_val),
			   .h_rdata(bus_data),
			   .h_wr_en(bus_wr_en),
			   .h_bytesel(bus_bytesel),
			   .h_compl(bus_ack),
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
			      .s_ras_n(s_ras_n),
			      .s_cas_n(s_cas_n),
			      .s_wr_en(s_wr_en),
			      .s_bytesel(s_bytesel),
			      .s_addr(s_addr),
			      .s_cs_n(s_cs_n),
			      .s_clken(s_clken),
			      .s_data(s_data),
			      .s_banksel(s_banksel));

endmodule
