module oldland_cpu(input wire clk,
		   output wire [31:0] i_addr,
		   input wire [31:0] i_data);

/* Fetch -> decode signals. */
wire [31:0] fd_pc;
wire [31:0] fd_pc_plus_4;
wire [31:0] fd_instr;

/* Execute -> fetch signals. */
wire [31:0] ef_branch_pc = em_alu_out;
wire ef_branch_taken;

/* Fetch stalling signals. */
wire stall_clear = ef_branch_taken;
wire stalling;

/* Decode signals. */
wire [2:0] d_ra_sel;
wire [2:0] d_rb_sel;

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
wire de_branch_ra;
wire [31:0] de_ra;
wire [31:0] de_rb;
wire [31:0] de_pc_plus_4;
wire [1:0] de_class;
wire de_is_call;
wire [1:0] de_mem_width;

/* Execute -> memory signals. */
wire [31:0] em_alu_out;
wire em_mem_load;
wire em_mem_store;
wire em_update_rd;
wire [2:0] em_rd_sel;
wire [31:0] em_wr_val;
wire [1:0] em_mem_width;

/* Writeback signals. */
wire [2:0] w_rd_sel = 3'b0;

oldland_fetch	fetch(.clk(clk),
		      .stall_clear(stall_clear),
		      .branch_pc(ef_branch_pc),
		      .branch_taken(ef_branch_taken),
		      .pc(fd_pc),
		      .pc_plus_4(fd_pc_plus_4),
		      .instr(fd_instr),
		      .fetch_addr(i_addr),
		      .fetch_data(i_data));

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
		       .branch_ra(de_branch_ra),
		       .pc_plus_4(fd_pc_plus_4),
		       .pc_plus_4_out(de_pc_plus_4),
		       .instr_class(de_class),
		       .is_call(de_is_call),
		       .mem_width(de_mem_width));

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
			.branch_ra(de_branch_ra),
			.branch_taken(ef_branch_taken),
			.alu_out(em_alu_out),
			.mem_load_out(em_mem_load),
			.mem_store_out(em_mem_store),
			.mem_width_out(em_mem_width),
			.wr_val(em_wr_val),
			.wr_result(em_update_rd),
			.rd_sel_out(em_rd_sel),
			.instr_class(de_class),
			.is_call(de_is_call));

oldland_regfile	regfile(.clk(clk),
			.ra_sel(d_ra_sel),
			.rb_sel(d_rb_sel),
			.rd_sel(w_rd_sel),
			.wr_en(0), /* Not until the writeback stage is implemented. */
			.wr_val(0),
			.ra(de_ra),
			.rb(de_rb));

endmodule
