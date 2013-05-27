/*
 * The fetch unit.  Outputs the instruction to execute, and the PC + 4.  This
 * means that PC relative addresses are actually relative to the PC + 4, but
 * that allows us to optimize call/ret as we don't need to calculate the
 * return address later and we already have it computed for the next
 * instruction address.
 *
 * The fetch unit does a partial decode of the instruction to determine
 * whether to stall or not.  Later on down the pipeline the stall is cleared
 * to continue new instructions.
 */
module oldland_fetch(input wire clk,
		     input wire stall_clear,
		     input wire [31:0] branch_pc,
		     input wire branch_taken,
		     output reg [31:0] pc,
		     output wire [31:0] pc_plus_4,
		     output wire [31:0] instr);

/*
 * Instructions are fetched from the next_pc on reset, so we need the initial
 * PC to be -4.
 */
initial pc		= 32'hfffffffc;

/* Next PC calculation logic. */
assign pc_plus_4	= pc + 32'd4;
wire [31:0] next_pc	= branch_taken ? branch_pc : pc_plus_4;

/*
 * Load/store or branches cause stalling.  This means a class of 01 or 10.
 *
 * If we detect a stall then issue NOP's until the stall is cleared.
 */
wire stalling		= (^instr[31:30] == 1'b1 || stalled) && !stall_clear;
reg stalled		= 1'b0;
assign instr		= stalled ? `INSTR_NOP : fetch_instr;
wire [31:0] fetch_instr;

sim_instr_rom rom(.clk(clk),
		  .addr(stalling ? pc : next_pc),
		  .data(fetch_instr));

always @(posedge clk)
	if (!stalling)
		pc <= next_pc;

always @(posedge clk) begin
	if (stalling)
		stalled <= 1'b1;
	else if (stall_clear)
		stalled <= 1'b0;
end

endmodule
