/*
 * Generate a variety of control signals from the input selection.  These
 * control signals include register selection, ALU opcode + operand selection
 * and load/store signals.
 *
 * Purely combinational logic.
 */
module oldland_decode(input wire [31:0] instr,
		      output wire [2:0] ra_sel,
		      output wire [2:0] rb_sel,
		      output wire [2:0] rd_sel,
		      output wire update_rd,
		      output wire [31:0] imm32,
		      output wire [3:0] alu_opc,
		      output wire [2:0] branch_condition,
		      output wire alu_op1_ra,
		      output wire alu_op2_rb,
		      output wire mem_load,
		      output wire mem_store,
		      output wire branch_ra);

assign alu_opc = instr[31:30] == 2'b00 ? instr[29:26] : 4'b0;

assign ra_sel = instr[5:3];
assign rb_sel = instr[2:0];
assign rd_sel = instr[8:6];

/*
 * Whether we store the result of the ALU operation in the destination
 * register or not.  This is almost all arithmetic operations apart from cmp
 * where we intentionally discard the result and load operations where the
 * register is update by the LSU later.
 */
assign update_rd = instr[31:30] == 2'b0 && instr[29:26] != 4'b1011;

assign branch_condition = instr[28:26];

/* Sign extended immediates. */
wire [31:0] imm16 = {{16{instr[25]}}, instr[25:10]};
wire [31:0] imm24 = {{8{instr[23]}}, instr[23:0]};

/*
 * The output immediate - either one of the sign extended immediates or
 * a special case for movhi - the 16 bit immediate shifted left 16 bits.
 */
assign imm32 = (instr[31:30] == 2'b01) ? imm24 :
	       (instr[31:26] == 6'b001011) ? {instr[25:10], 16'b0} : imm16;

assign branch_ra = instr[31:30] == 2'b01 && instr[25];
	
assign alu_op1_ra = (instr[31:30] == 2'b00 || instr[31:30] == 2'b10);
assign alu_op2_rb = (instr[31:30] == 2'b00 && instr[9]);

assign mem_load = instr[31:30] == 2'b10 && instr[28] == 1'b0;
assign mem_store = instr[31:30] == 2'b10 && instr[28] == 1'b1;

endmodule
