module oldland_cpu(input wire clk);

/* Fetch -> decode signals. */
wire [31:0] pc;
wire [31:0] pc_plus_4;
wire [31:0] instr;

/* Execute -> fetch signals. */
reg [31:0] branch_pc = 32'b0;
reg branch_taken = 1'b0;

/* Fetch stalling signals. */
reg stall_clear = 1'b1;
wire stalling;

/* Decode signals. */
wire [2:0] ra_sel;
wire [2:0] rb_sel;

/* Decode -> execute signals. */
wire [2:0] rd_sel;
wire update_rd;
wire [31:0] imm32;
wire [3:0] alu_opc;
wire [2:0] branch_condition;
wire alu_op1_ra;
wire alu_op2_ra;
wire mem_load;
wire mem_store;
wire branch_ra;
wire [31:0] ra;
wire [31:0] rb;

oldland_fetch	fetch(.clk(clk),
		      .stall_clear(stall_clear),
		      .branch_pc(branch_pc),
		      .branch_taken(branch_taken),
		      .pc(pc),
		      .pc_plus_4(pc_plus_4),
		      .instr(instr));

oldland_decode	decode(.clk(clk),
		       .instr(instr),
		       .ra_sel(ra_sel),
		       .rb_sel(rb_sel),
		       .rd_sel(rd_sel),
		       .update_rd(update_rd),
		       .imm32(imm32),
		       .alu_opc(alu_opc),
		       .branch_condition(branch_condition),
		       .alu_op1_ra(alu_op1_ra),
		       .alu_op2_rb(alu_op2_rb),
		       .mem_load(mem_load),
		       .mem_store(mem_store),
		       .branch_ra(branch_ra));

oldland_regfile	regfile(.clk(clk),
			.ra_sel(ra_sel),
			.rb_sel(rb_sel),
			.rd_sel(rd_sel),
			.wr_en(0), /* Not until the writeback stage is implemented. */
			.ra(ra),
			.rb(rb));

endmodule
