`include "oldland_defines.v"

/*
 * Instructions are fetched from the next_pc on reset.
 */
`ifndef OLDLAND_RESET_ADDR
`define OLDLAND_RESET_ADDR 32'h00000000
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
module oldland_fetch(input wire		clk,
		     input wire		rst,
		     output reg		i_access,
		     input wire		i_ack,
		     input wire		i_error,
		     input wire		stall_clear,
		     input wire [31:0]	branch_pc,
		     input wire		branch_taken,
		     output wire [31:0]	pc_plus_4,
		     output wire [31:0] instr,
		     output wire [29:0] fetch_addr,
		     input wire [31:0]	fetch_data,
		     input wire		run,
		     output wire	stopped,
		     output wire [31:0] dbg_pc,
		     input wire		dbg_pc_wr_en,
		     input wire [31:0]	dbg_pc_wr_val,
		     input wire [25:0]	vector_base,
		     input wire		illegal_instr,
		     input wire		data_abort);

localparam	STATE_RUNNING	= 2'b00;
localparam	STATE_STALLED	= 2'b01;
localparam	STATE_STOPPING	= 2'b10;
localparam	STATE_STOPPED	= 2'b11;
localparam	STOP_COUNT_RST	= 3'd5;

reg [1:0]	next_state = STATE_RUNNING;
reg [1:0]	state = STATE_RUNNING;

reg [31:0]	pc = `OLDLAND_RESET_ADDR;
assign		pc_plus_4 = pc + 32'd4;
reg [31:0]	next_pc = `OLDLAND_RESET_ADDR;
assign		dbg_pc = pc;

/*
 * Load/store or branches cause stalling.  This means a class of 01 or 10.
 *
 * If we detect a stall then issue NOP's until the stall is cleared.
 */
wire		should_stall = ^instr[31:30] == 1'b1;

/*
 * When stopping have a 5 cycle delay before signalling stopped.  We start the
 * counter once we are no longer stalling so there won't be any potentially
 * long memory accesses, we only have to handle integer ops here.
 */
reg [2:0]	stop_ctr = STOP_COUNT_RST;
assign		stopped = state == STATE_STOPPED;

assign		fetch_addr = next_pc[31:2];
assign		instr = i_ack ? fetch_data : `INSTR_NOP;

initial		i_access = 1'b1;

always @(*) begin
	if (dbg_pc_wr_en)
		next_pc = dbg_pc_wr_val;
	else if (i_error)
		next_pc = {vector_base, 6'h10};	/* Instruction fetch abort. */
	else if (data_abort)
		next_pc = {vector_base, 6'h14};	/* Data abort. */
	else if (illegal_instr)
		next_pc = {vector_base, 6'h4};	/* Illegal instruction. */
	else if (branch_taken)
		next_pc = branch_pc;
	else if (stall_clear ||
		 state == STATE_RUNNING && !should_stall)
		next_pc = pc_plus_4;
	else
		next_pc = pc;
end

always @(posedge clk)
	state <= next_state;

always @(*) begin
	case (state)
	STATE_RUNNING: begin
		/* Stall for branches and memory accesses. */
		if (should_stall)
			next_state = STATE_STALLED;
		else if (!run)
			next_state = STATE_STOPPING;
		else
			next_state = STATE_RUNNING;
	end
	STATE_STALLED: begin
		if (stall_clear && !run)
			next_state = STATE_STOPPING;
		else if (stall_clear || i_error)
			next_state = STATE_RUNNING;
		else
			next_state = STATE_STALLED;
	end
	STATE_STOPPING: begin
		if (~|stop_ctr)
			next_state = STATE_STOPPED;
		else
			next_state = STATE_STOPPING;
	end
	STATE_STOPPED: begin
		next_state = run ? STATE_RUNNING : STATE_STOPPED;
	end
	endcase
end

always @(*) begin
	case (state)
	STATE_RUNNING: i_access = run && !should_stall;
	STATE_STALLED: i_access = run && stall_clear;
	STATE_STOPPED: i_access = run;
	default: i_access = 1'b0;
	endcase
end

always @(posedge clk) begin
	if (rst)
		pc <= `OLDLAND_RESET_ADDR;
	else if (dbg_pc_wr_en)
		pc <= dbg_pc_wr_val;
	else if (state == STATE_STALLED && stall_clear)
		pc <= next_pc;
	else if (state == STATE_RUNNING && i_ack)
		pc <= next_pc;
end

always @(posedge clk)
	stop_ctr <= state == STATE_STOPPING ? stop_ctr - 3'd1 : STOP_COUNT_RST;

endmodule
