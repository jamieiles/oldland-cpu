module oldland_cpu(input wire clk,
		   /* Instruction bus. */
		   output wire [31:0] i_addr,
		   input wire [31:0] i_data,
		   /* Data bus. */
		   output wire [31:0] d_addr,
		   output wire [3:0] d_bytesel,
		   output wire d_wr_en,
		   output wire [31:0] d_wr_val,
		   input wire [31:0] d_data,
		   output wire d_access,
		   input wire d_ack,
		   input wire d_error,
		   /* Debug control signals. */
		   input wire dbg_clk,
		   input wire [1:0] dbg_addr,
		   input wire [31:0] dbg_din,
		   output wire [31:0] dbg_dout,
		   input wire dbg_wr_en,
		   input wire dbg_req,
		   output wire dbg_ack);

/* Fetch -> decode signals. */
wire [31:0] fd_pc_plus_4;
wire [31:0] fd_instr;

/* Execute -> fetch signals. */
wire ef_branch_taken;
wire ef_stall_clear;

/* Decode signals. */
wire [2:0] d_ra_sel;
wire [2:0] d_rb_sel;

reg [2:0] e_ra_sel = 3'b0;
reg [2:0] e_rb_sel = 3'b0;

/* Decode -> execute signals. */
wire [2:0] de_rd_sel;
wire de_update_rd;
wire [31:0] de_imm32;
wire [3:0] de_alu_opc;
wire [2:0] de_branch_condition;
wire de_alu_op1_ra;
wire de_alu_op2_rb;
wire de_mem_load;
wire de_mem_store;
wire [31:0] ra;
wire [31:0] rb;
wire [31:0] de_pc_plus_4;
wire [1:0] de_class;
wire de_is_call;
wire [1:0] de_mem_width;
wire de_update_flags;
reg [31:0] de_ra = 32'b0;
reg [31:0] de_rb = 32'b0;

/* Execute -> memory signals. */
wire [31:0] em_alu_out;
wire em_mem_load;
wire em_mem_store;
wire em_update_rd;
wire [2:0] em_rd_sel;
wire [31:0] em_wr_val;
wire [1:0] em_mem_width;
wire [31:0] em_mar;
wire [31:0] em_mdr;
wire em_mem_wr_en;

/* Memory -> writeback signals. */
wire [31:0] mw_wr_val;
wire mw_update_rd;
wire [2:0] mw_rd_sel;
wire mf_complete;

/* Fetch stalling signals. */
wire stall_clear = ef_stall_clear | mf_complete;
wire stalling;

/* Debug control signals. */
wire cpu_run;
wire cpu_stopped;
wire [2:0] dbg_reg_sel;
wire [31:0] dbg_reg_wr_val;
wire [31:0] dbg_reg_val;
wire dbg_reg_wr_en;
wire [31:0] dbg_pc;
wire [31:0] dbg_pc_wr_val;
wire dbg_pc_wr_en;

oldland_debug	debug(.clk(clk),
		      .dbg_clk(dbg_clk),
		      .addr(dbg_addr),
		      .din(dbg_din),
		      .dout(dbg_dout),
		      .wr_en(dbg_wr_en),
		      .req(dbg_req),
		      .ack(dbg_ack),
		      .run(cpu_run),
		      .stopped(cpu_stopped),
		      .dbg_reg_sel(dbg_reg_sel),
		      .dbg_reg_wr_val(dbg_reg_wr_val),
		      .dbg_reg_val(dbg_reg_val),
		      .dbg_reg_wr_en(dbg_reg_wr_en),
		      .dbg_pc(dbg_pc),
		      .dbg_pc_wr_val(dbg_pc_wr_val),
		      .dbg_pc_wr_en(dbg_pc_wr_en));

oldland_fetch	fetch(.clk(clk),
		      .stall_clear(stall_clear),
		      .branch_pc(em_alu_out),
		      .branch_taken(ef_branch_taken),
		      .pc_plus_4(fd_pc_plus_4),
		      .instr(fd_instr),
		      .fetch_addr(i_addr),
		      .fetch_data(i_data),
		      .run(cpu_run),
		      .stopped(cpu_stopped),
		      .dbg_pc(dbg_pc),
		      .dbg_pc_wr_en(dbg_pc_wr_en),
		      .dbg_pc_wr_val(dbg_pc_wr_val));

oldland_decode	decode(.clk(clk),
		       .instr(fd_instr),
		       .ra_sel(d_ra_sel),
		       .rb_sel(d_rb_sel),
		       .rd_sel(de_rd_sel),
		       .update_rd(de_update_rd),
		       .imm32(de_imm32),
		       .alu_opc(de_alu_opc),
		       .branch_condition(de_branch_condition),
		       .alu_op1_ra(de_alu_op1_ra),
		       .alu_op2_rb(de_alu_op2_rb),
		       .mem_load(de_mem_load),
		       .mem_store(de_mem_store),
		       .pc_plus_4(fd_pc_plus_4),
		       .pc_plus_4_out(de_pc_plus_4),
		       .instr_class(de_class),
		       .is_call(de_is_call),
		       .mem_width(de_mem_width),
		       .update_flags(de_update_flags));

oldland_exec	execute(.clk(clk),
			.ra(de_ra),
			.rb(de_rb),
			.imm32(de_imm32),
			.pc_plus_4(de_pc_plus_4),
			.rd_sel(de_rd_sel),
			.update_rd(de_update_rd),
			.alu_opc(de_alu_opc),
			.branch_condition(de_branch_condition),
			.alu_op1_ra(de_alu_op1_ra),
			.alu_op2_rb(de_alu_op2_rb),
			.mem_load(de_mem_load),
			.mem_store(de_mem_store),
			.mem_width(de_mem_width),
			.branch_taken(ef_branch_taken),
			.stall_clear(ef_stall_clear),
			.alu_out(em_alu_out),
			.mem_load_out(em_mem_load),
			.mem_store_out(em_mem_store),
			.mem_width_out(em_mem_width),
			.wr_val(em_wr_val),
			.wr_result(em_update_rd),
			.rd_sel_out(em_rd_sel),
			.instr_class(de_class),
			.is_call(de_is_call),
			.update_flags(de_update_flags),
			.mar(em_mar),
			.mdr(em_mdr),
			.mem_wr_en(em_mem_wr_en));

oldland_memory	mem(.clk(clk),
		    .load(em_mem_load),
		    .store(em_mem_store),
		    .addr(em_mar),
		    .mdr(em_mdr),
		    .mem_wr_en(em_mem_wr_en),
		    .width(em_mem_width),
		    .wr_val(em_wr_val),
		    .update_rd(em_update_rd),
		    .rd_sel(em_rd_sel),
		    .reg_wr_val(mw_wr_val),
		    .update_rd_out(mw_update_rd),
		    .rd_sel_out(mw_rd_sel),
		    .d_addr(d_addr),
		    .d_bytesel(d_bytesel),
		    .d_wr_en(d_wr_en),
		    .d_wr_val(d_wr_val),
		    .d_data(d_data),
		    .d_access(d_access),
		    .d_ack(d_ack),
		    .d_error(d_error),
		    .complete(mf_complete));

oldland_regfile	regfile(.clk(clk),
			.ra_sel(d_ra_sel),
			.rb_sel(d_rb_sel),
			.rd_sel(mw_rd_sel),
			.wr_en(mw_update_rd),
			.wr_val(mw_wr_val),
			.ra(ra),
			.rb(rb),
			.dbg_reg_sel(dbg_reg_sel),
			.dbg_reg_val(dbg_reg_val),
			.dbg_reg_wr_val(dbg_reg_wr_val),
			.dbg_reg_wr_en(dbg_reg_wr_en),
			.dbg_en(cpu_stopped));

/*
 * Forwarding logic.  We need to forward results from the end of the execute
 * stage back to the input of the ALU.
 */
always @(posedge clk) begin
	e_ra_sel <= d_ra_sel;
	e_rb_sel <= d_rb_sel;
end

always @(*) begin
	if (em_rd_sel == e_ra_sel && em_update_rd)
		de_ra = em_alu_out;
	else if (mw_rd_sel == e_ra_sel && mw_update_rd)
		de_ra = mw_wr_val;
	else
		de_ra = ra;

	if (em_rd_sel == e_rb_sel && em_update_rd)
		de_rb = em_alu_out;
	else if (mw_rd_sel == e_rb_sel && mw_update_rd)
		de_rb = mw_wr_val;
	else
		de_rb = rb;
end

endmodule
