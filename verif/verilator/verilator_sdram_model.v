module verilator_sdram_model(input wire clk,
			     input wire cs,
			     /* Host interface. */
			     input wire [31:2] h_addr,
			     input wire [31:0] h_wdata,
			     output reg [31:0] h_rdata,
			     input wire h_wr_en,
			     input wire [3:0] h_bytesel,
			     output reg h_compl,
			     output reg h_config_done,
			     /* SDRAM signals. */
			     output reg s_ras_n,
			     output reg s_cas_n,
			     output reg s_wr_en,
			     output reg [1:0] s_bytesel,
			     output reg [12:0] s_addr,
			     output reg s_cs_n,
			     output reg s_clken,
			     inout [15:0] s_data,
			     output reg [1:0] s_banksel);

parameter clkf = 50000000;

initial begin
	s_ras_n = 1'b0;
	s_cas_n = 1'b0;
	s_wr_en = 1'b0;
	s_bytesel = 2'b00;
	s_addr = 13'b0;
	s_cs_n = 1'b1;
	s_clken = 1'b0;
	s_data = 16'bz;
	s_banksel = 2'b00;

	h_rdata = 32'b0;
	h_compl = 1'b0;
	h_config_done = 1'b0;
end

reg [7:0] mem[32768 * 1024:0];

always @(posedge clk) begin
	h_compl <= 1'b0;
	h_config_done <= 1'b1;
	h_rdata <= 32'b0;

	if (cs) begin
		h_compl <= 1'b1;

		if (h_wr_en) begin
			if (h_bytesel[0])
				mem[{h_addr, 2'b00}] <= h_wdata[7:0];
			if (h_bytesel[1])
				mem[{h_addr, 2'b01}] <= h_wdata[15:8];
			if (h_bytesel[2])
				mem[{h_addr, 2'b10}] <= h_wdata[23:16];
			if (h_bytesel[3])
				mem[{h_addr, 2'b11}] <= h_wdata[31:24];
		end else begin
			h_rdata <= {mem[{h_addr, 2'b11}],
				    mem[{h_addr, 2'b10}],
				    mem[{h_addr, 2'b01}],
				    mem[{h_addr, 2'b00}]};
		end
	end
end

endmodule
