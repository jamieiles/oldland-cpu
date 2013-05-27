module oldland_memory(input wire clk,
		      input wire load,
		      input wire store,
		      input wire [31:0] addr,
		      input wire [1:0] width,
		      input wire [31:0] wr_val,
		      input wire update_rd,
		      input wire [2:0] rd_sel,
		      output wire [31:0] reg_wr_val,
		      output reg update_rd_out,
		      output reg [2:0] rd_sel_out,
		      output reg complete,
		      /* Signals to data bus */
		      output wire [31:0] d_addr,
		      output wire [3:0] d_bytesel,
		      output wire d_wr_en,
		      output wire [31:0] d_wr_val,
		      input wire [31:0] d_data,
		      output wire d_access);

initial begin
	update_rd_out = 1'b0;
	rd_sel_out = 3'b0;
	wr_val_bypass = 32'b0;
end

reg [31:0] wr_val_bypass;

assign d_addr = addr;
assign d_bytesel = 4'b1111;
assign d_wr_en = store;
assign d_wr_val = wr_val;
assign d_access = load | store;

assign reg_wr_val = complete ? d_data : wr_val_bypass;

always @(posedge clk) begin
	complete <= load | store;
	wr_val_bypass <= wr_val;
	update_rd_out <= update_rd;
	rd_sel_out <= rd_sel;
end

endmodule
