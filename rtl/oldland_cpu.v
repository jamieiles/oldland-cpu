module oldland_cpu(input wire clk);

/* Fetch -> decode signals. */
wire [31:0] fd_pc;
wire [31:0] fd_pc_plus_4;
wire [31:0] fd_instr;

/* Execute -> fetch signals. */
reg [31:0] ef_branch_pc = 32'b0;
reg ef_branch_taken = 1'b0;

/* Fetch stalling signals. */
reg stall_clear = 1'b1;
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

/* Writeback signals. */
wire [2:0] w_rd_sel = 3'b0;

oldland_fetch	fetch(.clk(clk),
		      .stall_clear(stall_clear),
		      .branch_pc(ef_branch_pc),
		      .branch_taken(ef_branch_taken),
		      .pc(fd_pc),
		      .pc_plus_4(fd_pc_plus_4),
		      .instr(fd_instr));

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
		       .branch_ra(de_branch_ra));

oldland_regfile	regfile(.clk(clk),
			.ra_sel(d_ra_sel),
			.rb_sel(d_rb_sel),
			.rd_sel(w_rd_sel),
			.wr_en(0), /* Not until the writeback stage is implemented. */
			.wr_val(0),
			.ra(de_ra),
			.rb(de_rb));

endmodule
