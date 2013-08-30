`include "oldland_defines.v"
module oldland_exec(input wire		clk,
		    input wire [31:0]	ra,
		    input wire [31:0]	rb,
		    input wire [31:0]	imm32,
		    input wire [31:0]	pc_plus_4,
		    input wire [3:0]	rd_sel,
		    input wire		update_rd,
		    input wire [4:0]	alu_opc,
		    input wire		alu_op1_ra,
		    input wire		alu_op1_rb,
		    input wire		alu_op2_rb,
		    input wire		mem_load,
		    input wire		mem_store,
		    input wire [1:0]	mem_width,
		    input wire [2:0]	branch_condition,
		    input wire [1:0]	instr_class,
		    input wire		is_call,
		    input wire		update_flags,
                    input wire [2:0]    cr_sel,
                    input wire          write_cr,
		    output reg		branch_taken,
		    output reg [31:0]	alu_out,
		    output reg		mem_load_out,
		    output reg		mem_store_out,
		    output reg [1:0]	mem_width_out,
		    output reg [31:0]	wr_val,
		    output reg		wr_result,
		    output reg [3:0]	rd_sel_out,
		    output reg		stall_clear,
		    output reg [31:0]	mar,
		    output reg [31:0]	mdr,
		    output reg		mem_wr_en,
                    input wire          is_swi,
		    input wire		is_rfe);

wire [31:0]	op1 = alu_op1_ra ? ra : alu_op1_rb ? rb : pc_plus_4;
wire [31:0]	op2 = alu_op2_rb ? rb : imm32;

reg [31:0]	alu_q = 32'b0;
reg		alu_c = 1'b0;
wire		alu_z = (op1 ^ op2) == 32'b0;

reg		branch_condition_met = 1'b0;

/* Status registers, not accessible by the programmer interface. */
reg		c_flag = 1'b0;
reg		z_flag = 1'b0;

reg [25:0]      vector_addr = 26'b0;

wire [1:0]      psr = {c_flag, z_flag};

reg [1:0]       saved_psr = 2'b0;
reg [31:0]      fault_address = 32'b0;

initial begin
	branch_taken = 1'b0;
	alu_out = 32'b0;
	mem_load_out = 1'b0;
	mem_store_out = 1'b0;
	wr_result = 1'b0;
	rd_sel_out = 4'b0;
	wr_val = 32'b0;
	mem_width_out = 2'b00;
	stall_clear = 1'b0;
	mar = 32'b0;
	mdr = 32'b0;
	mem_wr_en = 1'b0;
end

always @(*) begin
	alu_c = 1'b0;

	case (alu_opc)
	5'b00000: {alu_c, alu_q} = op1 + op2;
	5'b00001: {alu_c, alu_q} = op1 + op2 + {31'b0, c_flag};
	5'b00010: {alu_c, alu_q} = op1 - op2;
	5'b00011: {alu_c, alu_q} = op1 - op2 + {31'b0, c_flag};
	5'b00100: {alu_c, alu_q} = {1'b0, op1} << op2[4:0];
	5'b00101: alu_q = op1 >> op2[4:0];
	5'b00110: alu_q = op1 & op2;
	5'b00111: alu_q = op1 ^ op2;
	5'b01000: alu_q = op1 & ~(1 << op2[4:0]);
	5'b01001: alu_q = op1 | (1 << op2[4:0]);
	5'b01010: alu_q = op1 | op2;
	5'b01011: alu_q = op2;
	5'b01100: {alu_c, alu_q} = op1 - op2;
	5'b01101: alu_q = op1 | {16'b0, op2[15:0]};
	5'b01110: alu_q = op1 >>> op2;
	5'b01111: alu_q = op1;
	5'b10000: begin
                if (cr_sel == 3'b000) begin
                        alu_q = {vector_addr, 6'b0};
                end else if (cr_sel == 3'h1) begin
                        alu_q = {30'b0, c_flag, z_flag};
                end else if (cr_sel == 3'h2) begin
                        alu_q = {30'b0, saved_psr};
                end else if (cr_sel == 3'h3) begin
                        alu_q = fault_address;
                end else begin
                        alu_q = 32'b0;
                end
	end
        5'b10001: alu_q = {vector_addr, 6'h8};
	5'b10010: alu_q = fault_address;
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

/* CR0: exception vector table base address. */
always @(posedge clk)
        if (write_cr && cr_sel == 3'h0)
                vector_addr <= ra[31:6];

/* CR2: saved PSR. */
always @(posedge clk) begin
        if (is_swi)
                saved_psr <= psr;
        else if (write_cr && cr_sel == 3'h2)
                saved_psr <= ra[1:0];
end

/* CR3: fault address register. */
always @(posedge clk)
        if (is_swi)
                fault_address <= pc_plus_4;
	else if (write_cr && cr_sel == 3'h3)
		fault_address <= ra;

always @(posedge clk) begin
	alu_out <= alu_q;
	wr_result <= update_rd;
	rd_sel_out <= rd_sel;

	if (update_flags) begin
		z_flag <= alu_z;
		c_flag <= alu_c;
	end

	if (is_rfe) begin
		c_flag <= saved_psr[1];
		z_flag <= saved_psr[0];
	end

        /* CR1: PSR. */
        if (write_cr && cr_sel == 3'h1) begin
                c_flag <= ra[1];
                z_flag <= ra[0];
        end

	wr_val <= is_call ? pc_plus_4 :
		  mem_store ? op2 : alu_q;
end

always @(posedge clk) begin
	branch_taken <= instr_class == `CLASS_BRANCH &&
                (branch_condition_met || is_swi || is_rfe);
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

