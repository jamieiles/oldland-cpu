module oldland_regfile(input wire		clk,
		       input wire		rst,
		       input wire [3:0] 	ra_sel,
		       input wire [3:0] 	rb_sel,
		       input wire [3:0] 	rd_sel,
		       input wire		wr_en,
		       input wire [31:0]	wr_val,
		       output wire [31:0]	ra,
		       output wire [31:0]	rb,
		       input wire [3:0]		dbg_reg_sel,
		       output wire [31:0]	dbg_reg_val,
		       input wire [31:0]	dbg_reg_wr_val,
		       input wire		dbg_reg_wr_en,
		       input wire		dbg_en);

reg [31:0]	registers[15:0];
reg [4:0]	regno = 5'b0;

wire [3:0]	port_a_sel = dbg_en ? dbg_reg_sel : ra_sel;
reg [31:0]	port_a_val = 32'b0;

wire [3:0]	port_b_sel = rb_sel;
reg [31:0]	port_b_val = 32'b0;

wire [31:0]	wr_port_val = dbg_en ? dbg_reg_wr_val : wr_val;
wire		wr_port_wr_en = dbg_en ? dbg_reg_wr_en : wr_en;
wire [3:0]	wr_port_sel = dbg_en ? dbg_reg_sel : rd_sel;

assign		ra = port_a_val;
assign		rb = port_b_val;
assign		dbg_reg_val = port_a_val;

initial begin
	for (regno = 0; regno < 16; regno = regno + 5'b1)
		registers[regno[3:0]] = 32'b0;
end

always @(posedge clk) begin
	if (rst) begin
		for (regno = 0; regno < 16; regno = regno + 5'b1)
			registers[regno[3:0]] <= 32'b0;
	end else begin
		port_a_val <= (wr_en && port_a_sel == rd_sel) ? wr_port_val :
			registers[port_a_sel];
		port_b_val <= (wr_en && port_b_sel == rd_sel) ? wr_port_val :
			registers[port_b_sel];

		if (wr_port_wr_en)
			registers[wr_port_sel] <= wr_port_val;
	end
end

endmodule
