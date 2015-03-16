/*
 * Interrupt handling:
 *
 * - I bit in the PSR:
 *   0: interrupts disabled.
 *   1: interrupts enabled.
 * - Interrupts are level triggered, if irq_in goes high and PSR[I] == 1 then
 *   we'll service the interrupt.
 * - There is a possibility for an IRQ to happen at the same time as another
 *   exception such as illegal instruction or memory abort.  All abort
 *   handlers are entered with PSR[I] == 0 and all other exceptions have
 *   a higher priority than IRQ - the handlers can reenable interrupts to
 *   service IRQS.
 * - When we're ready to process an IRQ we flush the pipeline to avoid any
 *   side effects (such as control register writes in particular) and other
 *   exceptions.  If we're stalling for a memory access or branch then the
 *   pipeline is empty.  Otherwise we issue a pipeline flush which is just
 *   a NOP but the writeback stage signals that the pipeline is flushed.
 *
 * Dealing with interrupts and debugging:
 *
 * - When debugging, if we're single stepping then when we resume executing
 *   and take an interrupt we haven't yet executed the instruction at PC, so
 *   the next instruction after servicing the interrupt should be PC.
 * - If we're running and take an interrupt then we've just executed an
 *   instruction, we need to return to the next instruction - either pc + 4 or
 *   the target of a taken branch.
 *
 * Exception Priorities:
 *
 * 1. Reset.
 * 2. Data abort.
 * 3. Software interrupt.
 * 4. Illegal instruction.
 * 5. Interrupt.
 * 6. Instruction fetch abort.
 *
 * With this scheme we should always process the exception for the instruction
 * that has made the most progress through the pipeline so returning from
 * that exception by re-executing the instruction or starting from the next
 * should order exceptions correctly.
 */

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
		     input wire		irq_req,
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
		     input wire		data_abort,
		     output wire	i_fetched,
		     input wire		pipeline_busy,
		     input wire		irqs_enabled,
		     output wire	exception_disable_irqs,
		     output wire	exception_disable_mmu,
		     input wire		decode_exception,
		     output wire	irq_start,
		     output reg [31:0]	exception_fault_address,
		     input wire		bkpt_hit,
		     input wire [31:2]	dtlb_miss_handler,
		     input wire [31:2]	itlb_miss_handler,
		     input wire		dtlb_miss,
		     input wire		itlb_miss);

localparam	STATE_RUNNING	= 3'b000;
localparam	STATE_STALLED	= 3'b001;
localparam	STATE_STOPPING	= 3'b010;
localparam	STATE_STOPPED	= 3'b011;
localparam	STATE_FLUSHING	= 3'b100;

reg [2:0]	next_state = STATE_RUNNING;
reg [2:0]	state = STATE_RUNNING;

reg [31:0]	pc = `OLDLAND_RESET_ADDR;
assign		pc_plus_4 = pc + 32'd4;
reg [31:0]	next_pc = `OLDLAND_RESET_ADDR;
assign		dbg_pc = pc;
reg		itlb_miss_pending = 1'b0;
reg		branch_pending = 1'b0;

/*
 * Load/store or branches cause stalling.  This means a class of 01 or 10.
 *
 * If we detect a stall then issue NOP's until the stall is cleared.
 */
wire		should_stall = ^instr[31:30] == 1'b1 && ~illegal_instr;
wire		flushing = state == STATE_FLUSHING;

assign		stopped = state == STATE_STOPPED;

assign		fetch_addr = next_pc[31:2];
assign		instr = i_ack && !itlb_miss && !flushing ? fetch_data : `INSTR_NOP;

reg		fetching = 1'b0;
assign		i_fetched = i_ack && ~itlb_miss && ~flushing;
wire		take_irq = irqs_enabled && !pipeline_busy && irq_req && (i_access && !fetching);
wire		do_itlb_miss = !pipeline_busy && itlb_miss_pending && (i_access && !fetching);
assign		exception_disable_irqs = data_abort |
					 take_irq |
					 decode_exception |
					 dtlb_miss |
					 itlb_miss |
					 i_error;
assign		irq_start = take_irq;
reg		starting_irq = 1'b0;
reg		irq_return_to_this_instr = 1'b0;

assign		exception_disable_mmu = dtlb_miss | do_itlb_miss;

initial	begin
	i_access = 1'b1;
	branch_pending = 1'b0;
end

always @(posedge clk) begin
	if (branch_taken)
		branch_pending <= 1'b1;
	if (i_ack || take_irq)
		branch_pending <= 1'b0;
end

always @(*) begin
	if (state == STATE_STOPPED)
		exception_fault_address = pc;
	else if (branch_taken)
		exception_fault_address = branch_pc;
	else if ((branch_pending && !i_ack) || irq_return_to_this_instr)
		exception_fault_address = pc;
	else
		exception_fault_address = pc_plus_4;
end

always @(posedge clk) begin
	if (rst)
		starting_irq <= 1'b0;
	else if (starting_irq && i_ack)
		starting_irq <= 1'b0;
	else if (take_irq)
		starting_irq <= 1'b1;
end

always @(posedge clk) begin
	if (rst)
		itlb_miss_pending <= 1'b0;
	else if (itlb_miss)
		itlb_miss_pending <= 1'b1;
	else if (do_itlb_miss)
		itlb_miss_pending <= 1'b0;
end

always @(*) begin
	if (dbg_pc_wr_en)
		next_pc = dbg_pc_wr_val;
	else if (i_error)
		next_pc = {vector_base, 6'h10};	/* Instruction fetch abort. */
	else if (data_abort)
		next_pc = {vector_base, 6'h14};	/* Data abort. */
	else if (illegal_instr)
		next_pc = {vector_base, 6'h4};	/* Illegal instruction. */
	else if (take_irq || starting_irq)
		next_pc = {vector_base, 6'hc};  /* Interrupt. */
	else if (do_itlb_miss)
		next_pc = {itlb_miss_handler, 2'b0}; /* ITLB miss. */
	else if (dtlb_miss)
		next_pc = {dtlb_miss_handler, 2'b0}; /* DTLB miss. */
	else if (branch_taken)
		next_pc = branch_pc;
	else if (stall_clear || (i_ack && !should_stall))
		next_pc = pc_plus_4;
	else
		next_pc = pc;
end

always @(posedge clk)
	state <= next_state;

always @(posedge clk) begin
	if ((i_ack && !i_access) || itlb_miss || itlb_miss_pending)
		fetching <= 1'b0;
	else if (i_access)
		fetching <= 1'b1;
end

always @(*) begin
	case (state)
	STATE_RUNNING: begin
		/* Stall for branches and memory accesses. */
		if (irq_req && irqs_enabled && pipeline_busy)
			next_state = STATE_FLUSHING;
		else if (itlb_miss && pipeline_busy)
			next_state = STATE_FLUSHING;
		else if (should_stall)
			next_state = STATE_STALLED;
		else if (!run && (i_access | !fetching))
			next_state = STATE_STOPPING;
		else
			next_state = STATE_RUNNING;
	end
	STATE_STALLED: begin
		if (stall_clear && !run)
			next_state = STATE_STOPPING;
		else if (stall_clear || i_error || itlb_miss)
			next_state = STATE_RUNNING;
		else
			next_state = STATE_STALLED;
	end
	STATE_STOPPING: begin
		next_state = pipeline_busy ? STATE_STOPPING : STATE_STOPPED;
	end
	STATE_STOPPED: begin
		next_state = run ? STATE_RUNNING : STATE_STOPPED;
	end
	STATE_FLUSHING: begin
		if (!run)
			next_state = STATE_STOPPING;
		else if (pipeline_busy)
			next_state = STATE_FLUSHING;
		else
			next_state = STATE_RUNNING;
	end
	default: begin
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
	else if (((i_ack && !itlb_miss) || take_irq || do_itlb_miss) && !bkpt_hit && state != STATE_FLUSHING)
		pc <= next_pc;
end

/*
 * If we advance the PC during pipeline flushing for an IRQ then we won't
 * begin the instruction and need to return to the new PC, not the next
 * instruction.
 */
always @(posedge clk) begin
	if (i_ack && irqs_enabled && irq_req && state == STATE_FLUSHING)
		irq_return_to_this_instr <= 1'b1;
	if (take_irq)
		irq_return_to_this_instr <= 1'b0;
end

endmodule
