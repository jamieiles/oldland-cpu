module oldland_regfile(input wire clk,
		       input wire [2:0] ra_sel,
		       input wire [2:0] rb_sel,
		       input wire [2:0] rd_sel,
		       input wire wr_en,
		       input wire [31:0] wr_val,
		       output reg [31:0] ra,
		       output reg [31:0] rb);

reg [31:0] registers[7:0];
reg [3:0] regno = 4'b0;

initial begin
	for (regno = 0; regno < 8; regno = regno + 1)
		registers[regno[2:0]] = 32'b0;
	ra = 32'b0;
	rb = 32'b0;
end

always @(posedge clk) begin
	ra <= registers[ra_sel];
	rb <= registers[rb_sel];

	if (wr_en)
		registers[rd_sel] <= wr_val;
end

endmodule
