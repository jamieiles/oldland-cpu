module oldland_memory(input wire clk,
		      input wire load,
		      input wire store,
		      input wire [31:0] addr,
		      input wire [31:0] mdr,
		      input wire mem_wr_en,
		      input wire [1:0] width,
		      input wire [31:0] wr_val,
		      input wire update_rd,
		      input wire [2:0] rd_sel,
		      output wire [31:0] reg_wr_val,
		      output wire update_rd_out,
		      output wire [2:0] rd_sel_out,
		      output wire complete,
		      /* Signals to data bus */
		      output wire [31:0] d_addr,
		      output reg [3:0] d_bytesel,
		      output wire d_wr_en,
		      output reg [31:0] d_wr_val,
		      input wire [31:0] d_data,
		      output wire d_access,
		      input wire d_ack,
		      input wire d_error);

reg [31:0] wr_val_bypass;
reg update_rd_bypass = 1'b0;
reg [31:0] mem_rd_val;

assign d_addr = {addr[31:2], 2'b00};
assign d_wr_en = mem_wr_en;
assign d_access = load | store;

reg [2:0] rd_sel_out_bypass = 3'b0;
reg [2:0] mem_rd = 3'b0;
reg mem_update_rd = 1'b0;

assign reg_wr_val = complete ? mem_rd_val : wr_val_bypass;
assign complete = d_ack;
assign update_rd_out = complete ? mem_update_rd : update_rd_bypass;
assign rd_sel_out = complete ? mem_rd : rd_sel_out_bypass;

initial begin
	wr_val_bypass = 32'b0;
	d_bytesel = 4'b0;
	d_wr_val = 32'b0;
	mem_rd_val = 32'b0;
end

always @(posedge clk) begin
	update_rd_bypass <= update_rd;
	wr_val_bypass <= wr_val;
	rd_sel_out_bypass <= rd_sel;

	if (load)
		mem_rd <= rd_sel;
	if (store || load)
		mem_update_rd <= load;
end

/* Byte enables and rotated data write value. */
always @(*) begin
	case (width)
	2'b10: begin
		d_bytesel = 4'b1111;
		d_wr_val = mdr;
		mem_rd_val = d_data;
	end
	2'b01: begin
		d_bytesel = 4'b0011 << (addr[1] * 2);
		d_wr_val = mdr << (addr[1] * 16);
		mem_rd_val = d_data >> (addr[1] * 16);
	end
	2'b00: begin
		d_bytesel = 4'b0001 << addr[1:0];
		d_wr_val = mdr << (addr[1:0] * 8);
		mem_rd_val = d_data >> (addr[1:0] * 8);
	end
	default: begin
		d_bytesel = 4'b1111;
		d_wr_val = mdr;
		mem_rd_val = d_data;
	end
	endcase
end

endmodule
