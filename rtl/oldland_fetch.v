`include "oldland_defines.v"

/*
 * Instructions are fetched from the next_pc on reset, so we need the initial
 * PC to be -4.
 */
`ifndef OLDLAND_RESET_ADDR
`define OLDLAND_RESET_ADDR 32'hfffffffc
`endif /* !OLDLAND_RESET_ADDR */

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
		     output wire [31:0] pc_plus_4,
		     output wire [31:0] instr,
		     output wire [31:0] fetch_addr,
		     input wire [31:0] fetch_data,
		     input wire run,
		     output reg stopped,
		     output wire [31:0] dbg_pc,
		     input wire dbg_pc_wr_en,
		     input wire [31:0] dbg_pc_wr_val);

reg [31:0]	pc		= `OLDLAND_RESET_ADDR;

/* Next PC calculation logic. */
assign		pc_plus_4	= pc + 32'd4;
reg [31:0]	next_pc;
assign		dbg_pc		= pc;

/*
 * Load/store or branches cause stalling.  This means a class of 01 or 10.
 *
 * If we detect a stall then issue NOP's until the stall is cleared.
 */
reg		stalled		= 1'b0;
wire		stalling	= (^instr[31:30] == 1'b1 || stalled) &&
					!stall_clear;
assign		instr		= stalled || stopping ? `INSTR_NOP :
					fetch_data;
reg		stopping	= 1'b0;
reg [2:0]	stop_ctr	= 3'd5;

assign		fetch_addr	= stalling || stopping || !run ? pc : next_pc;

initial		stopped		= 1'b0;

always @(*) begin
	if (dbg_pc_wr_en)
		next_pc = dbg_pc_wr_val;
	else if (branch_taken)
		next_pc = branch_pc;
	else
		next_pc = pc_plus_4;
end

always @(posedge clk)
	if (!stalling && !stopping)
		pc <= next_pc;

always @(posedge clk) begin
	if (stalling)
		stalled <= 1'b1;
	else if (stall_clear)
		stalled <= 1'b0;

	if (!run && !stalling)
		stopping <= 1'b1;

	if (run) begin
		stopping <= 1'b0;
		stopped <= 1'b0;
		stop_ctr <= 3'd5;
	end else begin
		if (stopping && |stop_ctr && !stalling)
			stop_ctr <= stop_ctr - 3'b1;
		if (~|stop_ctr)
			stopped <= 1'b1;
	end
end

/*
 * To step the pipeline:
 *
 * - wait for any stall to resolve - we don't want to lose a branch.
 * - mark the pipeline as stalling, allow enough cycles to flush any
 *   instruction in the pipeline.
 * - issue nops until run goes high, resume execution.
 */

endmodule
