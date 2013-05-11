module fetch_tb();

reg clk = 1'b0;

always #1 clk = ~clk;

reg stall_clear = 1'b0;
reg [31:0] branch_pc = 32'h00000000;
reg branch_taken = 1'b0;

wire stalling;
wire [31:0] pc;
wire [31:0] pc_plus_4;
wire [31:0] instr;

oldland_fetch fetch(.clk(clk),
		    .stalling(stalling),
		    .stall_clear(stall_clear),
		    .branch_pc(branch_pc),
		    .branch_taken(branch_taken),
		    .pc(pc),
		    .pc_plus_4(pc_plus_4),
		    .instr(instr));

initial begin
	$dumpfile("pc.vcd");
	$dumpvars(0, fetch_tb);
	#256 $finish;
end

always @(*) begin
	branch_taken = 1'b0;
	if (pc == 32'hc)
		branch_taken = 1'b1;
end

always @(posedge clk) begin
	stall_clear <= 1'b0;
	if (stalling) begin
		stall_clear <= 1'b1;
		#2;
		stall_clear <= 1'b0;
	end
end

endmodule
