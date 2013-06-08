`include "oldland_defines.v"
module oldland_exec(input wire clk,
		    input wire [31:0] ra,
		    input wire [31:0] rb,
		    input wire [31:0] imm32,
		    input wire [31:0] pc_plus_4,
		    input wire [2:0] rd_sel,
		    input wire update_rd,
		    input wire [3:0] alu_opc,
		    input wire alu_op1_ra,
		    input wire alu_op2_rb,
		    input wire mem_load,
		    input wire mem_store,
		    input wire [1:0] mem_width,
		    input wire [2:0] branch_condition,
		    input wire [1:0] instr_class,
		    input wire is_call,
		    input wire update_flags,
		    output reg branch_taken,
		    output reg [31:0] alu_out,
		    output reg mem_load_out,
		    output reg mem_store_out,
		    output reg [1:0] mem_width_out,
		    output reg [31:0] wr_val,
		    output reg wr_result,
		    output reg [2:0] rd_sel_out,
		    output reg stall_clear,
		    output reg [31:0] mar,
		    output reg [31:0] mdr,
		    output reg mem_wr_en);

initial begin
	branch_taken = 1'b0;
	alu_out = 32'b0;
	mem_load_out = 1'b0;
	mem_store_out = 1'b0;
	wr_result = 1'b0;
	rd_sel_out = 3'b0;
	wr_val = 32'b0;
	mem_width_out = 2'b00;
	stall_clear = 1'b0;
	mar = 32'b0;
	mdr = 32'b0;
	mem_wr_en = 1'b0;
end

wire [31:0] op1 = alu_op1_ra ? ra : pc_plus_4;
wire [31:0] op2 = alu_op2_rb ? rb : imm32;
reg [31:0] alu_q = 32'b0;
reg alu_c = 1'b0;
wire alu_z = (op1 ^ op2) == 32'b0;
reg branch_condition_met = 1'b0;

/* Status registers, not accessible by the programmer interface. */
reg c_flag = 1'b0;
reg z_flag = 1'b0;

always @(*) begin
	alu_c = 1'b0;

	case (alu_opc)
	4'b0000: {alu_c, alu_q} = op1 + op2;
	4'b0001: {alu_c, alu_q} = op1 + op2 + {31'b0, c_flag};
	4'b0010: {alu_c, alu_q} = op1 - op2;
	4'b0011: {alu_c, alu_q} = op1 - op2 + {31'b0, c_flag};
	4'b0100: {alu_c, alu_q} = {1'b0, op1} << op2[4:0];
	4'b0101: alu_q = op1 >> op2[4:0];
	4'b0110: alu_q = op1 & op2;
	4'b0111: alu_q = op1 ^ op2;
	4'b1000: alu_q = op1 & ~(1 << op2[4:0]);
	4'b1001: alu_q = op1 | (1 << op2[4:0]);
	4'b1010: alu_q = op1 | op2;
	4'b1011: alu_q = op2;
	4'b1100: {alu_c, alu_q} = op1 - op2;
	4'b1101: alu_q = op1 | {16'b0, op2[15:0]};
	4'b1110: alu_q = op1 >>> op2;
	4'b1111: alu_q = op1;
	default: alu_q = 32'b0;
	endcase
end

always @(*) begin
	case (branch_condition)
	3'b111: branch_condition_met = 1'b1;
	3'b001: branch_condition_met = !z_flag;
	3'b010: branch_condition_met = z_flag;
	3'b011: branch_condition_met = !c_flag;
	3'b100: branch_condition_met = c_flag;
	default: branch_condition_met = 1'b0;
	endcase
end

always @(posedge clk) begin
	alu_out <= alu_q;
	wr_result <= update_rd;
	rd_sel_out <= rd_sel;

	if (update_flags) begin
		z_flag <= alu_z;
		c_flag <= alu_c;
	end

	wr_val <= is_call ? pc_plus_4 :
		  mem_store ? op2 : alu_q;
end

always @(posedge clk) begin
	branch_taken <= instr_class == `CLASS_BRANCH && branch_condition_met;
	stall_clear <= instr_class == `CLASS_BRANCH;
end

always @(posedge clk) begin
	mem_load_out <= mem_load;
	mem_store_out <= mem_store;
	if (mem_store || mem_load) begin
		mem_width_out <= mem_width;
		mar <= alu_q;
		if (mem_store)
			mdr <= rb;
	end
	mem_wr_en <= mem_store;
end

endmodule

