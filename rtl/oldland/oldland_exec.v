module oldland_exec(input wire		clk,
		    input wire		rst,
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
		    input wire [3:0]	branch_condition,
		    input wire [1:0]	instr_class,
		    input wire		is_call,
		    input wire		update_carry,
		    input wire		update_flags,
                    input wire [2:0]    cr_sel,
                    input wire          write_cr,
                    input wire          spsr,
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
		    input wire		is_rfe,
		    output wire [25:0]	vector_base,
		    input wire		data_abort,
		    input wire		exception_start,
		    input wire		i_valid,
		    output reg		i_valid_out,
		    output reg		irqs_enabled,
		    input wire		exception_disable_irqs,
		    input wire		exception_disable_mmu,
		    input wire [2:0]	dbg_cr_sel,
		    output wire [31:0]	dbg_cr_val,
		    input wire [31:0]	dbg_cr_wr_val,
		    input wire		dbg_cr_wr_en,
		    input wire		irq_start,
		    input wire [31:0]	exception_fault_address,
		    output wire [2:0]	cpuid_sel,
		    input wire [31:0]	cpuid_val,
		    input wire		cache_instr,
		    output reg		cache_instr_out,
		    output reg [2:0]	cache_op,
		    output reg		icache_enabled,
		    output reg		dcache_enabled,
                    output reg          tlb_enabled,
		    input wire		dtlb_miss,
                    output reg [31:2]   dtlb_miss_handler,
                    output reg [31:2]   itlb_miss_handler,
		    output reg		user_mode);

wire [31:0]	op1 = alu_op1_ra ? ra : alu_op1_rb ? rb : pc_plus_4;
wire [31:0]	op2 = alu_op2_rb ? rb : imm32;

reg [31:0]	alu_q = 32'b0;
reg		alu_c = 1'b0;
wire		alu_z = (op1 ^ op2) == 32'b0;
reg		alu_n = 1'b0;
reg		alu_o = 1'b0;

reg		branch_condition_met = 1'b0;

/* Status registers, not accessible by the programmer interface. */
reg		c_flag = 1'b0;
reg		z_flag = 1'b0;
reg		o_flag = 1'b0;
reg		n_flag = 1'b0;

reg [25:0]      vector_addr = 26'b0;

wire [8:0]      psr = {user_mode, tlb_enabled, icache_enabled, dcache_enabled,
		       irqs_enabled, n_flag, o_flag, c_flag, z_flag};

reg [8:0]       saved_psr = 9'b0;
reg [31:0]      fault_address = 32'b0;
reg [31:0]	data_fault_address = 32'b0;

assign		vector_base = vector_addr;

wire [31:0]	control_regs[7:0];
assign		control_regs[0] = {vector_addr, 6'b0};
assign		control_regs[1] = {23'b0, user_mode, tlb_enabled,
				   icache_enabled, dcache_enabled,
				   irqs_enabled, n_flag, o_flag, c_flag,
				   z_flag};
assign		control_regs[2] = {23'b0, saved_psr};
assign		control_regs[3] = fault_address;
assign		control_regs[4] = data_fault_address;
assign		control_regs[5] = {dtlb_miss_handler, 2'b0};
assign		control_regs[6] = {itlb_miss_handler, 2'b0};
assign		control_regs[7] = 32'b0;

assign		dbg_cr_val = control_regs[dbg_cr_sel];

wire [31:0]	read_cr_val = control_regs[cr_sel];

assign		cpuid_sel = op2[2:0];

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
	i_valid_out = 1'b0;
	irqs_enabled = 1'b0;
	cache_instr_out = 1'b0;
	cache_op = 3'b00;
	icache_enabled = 1'b0;
	dcache_enabled = 1'b0;
        tlb_enabled = 1'b0;
        dtlb_miss_handler = 30'b0;
        itlb_miss_handler = 30'b0;
	user_mode = 1'b0;
end

always @(*) begin
	alu_c = 1'b0;
	alu_o = 1'b0;
	alu_n = 1'b0;

	case (alu_opc)
	`ALU_OPC_ADD:   {alu_c, alu_q} = op1 + op2;
	`ALU_OPC_ADDC:  {alu_c, alu_q} = op1 + op2 + {31'b0, c_flag};
	`ALU_OPC_SUB:   {alu_c, alu_q} = op1 - op2;
	`ALU_OPC_SUBC:  {alu_c, alu_q} = op1 - op2 - {31'b0, c_flag};
	`ALU_OPC_MUL:	{alu_c, alu_q} = op1 * op2;
	`ALU_OPC_LSL:   {alu_c, alu_q} = {1'b0, op1} << op2[4:0];
	`ALU_OPC_LSR:   alu_q = op1 >> op2[4:0];
	`ALU_OPC_AND:   alu_q = op1 & op2;
	`ALU_OPC_XOR:   alu_q = op1 ^ op2;
        `ALU_OPC_BIC:   alu_q = op1 & ~(1 << op2[4:0]);
	`ALU_OPC_BST:   alu_q = op1 | (1 << op2[4:0]);
	`ALU_OPC_OR:    alu_q = op1 | op2;
	`ALU_OPC_COPYB: alu_q = op2;
	`ALU_OPC_CMP: begin
		{alu_c, alu_q} = op1 - op2;
		alu_c = ~alu_c;
		alu_o = op1[31] ^ op2[31] && alu_q[31] == op2[31];
		alu_n = alu_q[31];
	end
	`ALU_OPC_MOVHI: alu_q = op1 | {16'b0, op2[15:0]};
	`ALU_OPC_ASR:   alu_q = $signed(op1) >>> op2[4:0];
	`ALU_OPC_COPYA: alu_q = op1;
	`ALU_OPC_GCR:	alu_q = read_cr_val;
        `ALU_OPC_SWI:   alu_q = {vector_addr, 6'h8};
	`ALU_OPC_RFE:   alu_q = fault_address;
	`ALU_OPC_CPUID:	alu_q = cpuid_val;
        `ALU_OPC_GPSR:  alu_q = {28'b0, psr[3:0]};
	default:        alu_q = 32'b0;
	endcase
end

`define BRANCH_CC_NE	4'b0001
`define BRANCH_CC_EQ	4'b0010
`define BRANCH_CC_GT	4'b0011
`define BRANCH_CC_LT	4'b0100
`define BRANCH_CC_GTS	4'b0101
`define BRANCH_CC_LTS	4'b0110
`define BRANCH_CC_B 	4'b0111
`define BRANCH_CC_GTE   4'b1000
`define BRANCH_CC_GTES  4'b1001
`define BRANCH_CC_LTE   4'b1010
`define BRANCH_CC_LTES  4'b1011

always @(*) begin
	case (branch_condition)
	`BRANCH_CC_NE:   branch_condition_met = !z_flag;
	`BRANCH_CC_EQ:   branch_condition_met = z_flag;
	`BRANCH_CC_GT:   branch_condition_met = c_flag && !z_flag;
	`BRANCH_CC_LT:   branch_condition_met = !c_flag;
	`BRANCH_CC_GTS:  branch_condition_met = !z_flag && (n_flag == o_flag);
	`BRANCH_CC_LTS:  branch_condition_met = n_flag != o_flag;
	`BRANCH_CC_B:    branch_condition_met = 1'b1;
	`BRANCH_CC_GTE:  branch_condition_met = c_flag;
	`BRANCH_CC_GTES: branch_condition_met = n_flag == o_flag;
	`BRANCH_CC_LTE:  branch_condition_met = !c_flag || z_flag;
	`BRANCH_CC_LTES: branch_condition_met = (n_flag != o_flag) || z_flag;
	default: branch_condition_met = 1'b0;
	endcase
end

/* CR0: exception vector table base address. */
always @(posedge clk)
	if (rst)
		vector_addr <= 26'b0;
	else if (dbg_cr_wr_en && dbg_cr_sel == 3'h0)
		vector_addr <= dbg_cr_wr_val[31:6];
	else if (write_cr && cr_sel == 3'h0)
                vector_addr <= ra[31:6];

/* CR2: saved PSR. */
always @(posedge clk) begin
	if (rst)
		saved_psr <= 9'b0;
	else if (dbg_cr_wr_en && dbg_cr_sel == 3'h2)
		saved_psr <= dbg_cr_wr_val[8:0];
        else if (is_swi || exception_start || exception_disable_irqs ||
                 irq_start || data_abort || exception_disable_mmu)
                saved_psr <= psr;
        else if (write_cr && cr_sel == 3'h2)
                saved_psr <= ra[8:0];
end

/* CR3: fault address register. */
always @(posedge clk)
	if (rst)
		fault_address <= 32'b0;
	else if (dbg_cr_wr_en && dbg_cr_sel == 3'h3)
		fault_address <= dbg_cr_wr_val;
	else if (irq_start)
		fault_address <= exception_fault_address;
	else if (exception_disable_irqs || exception_disable_mmu)
                fault_address <= pc_plus_4;
	else if (write_cr && cr_sel == 3'h3)
		fault_address <= ra;

/* CR4: data fault address register. */
always @(posedge clk)
	if (rst)
		data_fault_address <= 32'b0;
	else if (dbg_cr_wr_en && dbg_cr_sel == 3'h4)
		data_fault_address <= dbg_cr_wr_val;
	else if (data_abort || dtlb_miss)
		data_fault_address <= mar;
	else if (write_cr && cr_sel == 3'h4)
		data_fault_address <= ra;

/* CR5: DTLB miss handler physical address. */
always @(posedge clk)
	if (rst)
		dtlb_miss_handler <= 30'b0;
	else if (dbg_cr_wr_en && dbg_cr_sel == 3'h5)
		dtlb_miss_handler <= dbg_cr_wr_val[31:2];
	else if (write_cr && cr_sel == 3'h5)
		dtlb_miss_handler <= ra[31:2];

/* CR6: ITLB miss handler physical address. */
always @(posedge clk)
	if (rst)
		itlb_miss_handler <= 30'b0;
	else if (dbg_cr_wr_en && dbg_cr_sel == 3'h6)
		itlb_miss_handler <= dbg_cr_wr_val[31:2];
	else if (write_cr && cr_sel == 3'h6)
		itlb_miss_handler <= ra[31:2];

always @(posedge clk) begin
	if (rst) begin
		alu_out <= 32'b0;
		wr_result <= 1'b0;
		z_flag <= 1'b0;
		c_flag <= 1'b0;
		n_flag <= 1'b0;
		o_flag <= 1'b0;
		irqs_enabled <= 1'b0;
		icache_enabled <= 1'b0;
		dcache_enabled <= 1'b0;
                tlb_enabled <= 1'b0;
		user_mode <= 1'b0;
	end else begin
		alu_out <= alu_q;
		wr_result <= update_rd;
		rd_sel_out <= rd_sel;

		if (update_flags) begin
			z_flag <= alu_z;
			n_flag <= alu_n;
			o_flag <= alu_o;
		end

		if (update_carry)
			c_flag <= alu_c;

		if (exception_disable_irqs || is_swi) begin
			irqs_enabled <= 1'b0;
			user_mode <= 1'b0;
		end

		if (exception_disable_mmu) begin
			tlb_enabled <= 1'b0;
			user_mode <= 1'b0;
		end

		if (is_rfe) begin
			user_mode <= saved_psr[8];
			tlb_enabled <= saved_psr[7];
			icache_enabled <= saved_psr[6];
			dcache_enabled <= saved_psr[5];
			irqs_enabled <= saved_psr[4];
			n_flag <= saved_psr[3];
			o_flag <= saved_psr[2];
			c_flag <= saved_psr[1];
			z_flag <= saved_psr[0];
		end

		/* CR1: PSR. */
		if (write_cr && cr_sel == 3'h1) begin
			user_mode <= ra[8];
			tlb_enabled <= ra[7];
			icache_enabled <= ra[6];
			dcache_enabled <= ra[5];
			irqs_enabled <= ra[4];
			n_flag <= ra[3];
			o_flag <= ra[2];
			c_flag <= ra[1];
			z_flag <= ra[0];
                end else if (spsr) begin
			n_flag <= ra[3];
			o_flag <= ra[2];
			c_flag <= ra[1];
			z_flag <= ra[0];
		end else if (dbg_cr_wr_en && dbg_cr_sel == 3'h1) begin
			user_mode <= dbg_cr_wr_val[8];
			tlb_enabled <= dbg_cr_wr_val[7];
			icache_enabled <= dbg_cr_wr_val[6];
			dcache_enabled <= dbg_cr_wr_val[5];
			irqs_enabled <= dbg_cr_wr_val[4];
			n_flag <= dbg_cr_wr_val[3];
			o_flag <= dbg_cr_wr_val[2];
			c_flag <= dbg_cr_wr_val[1];
			z_flag <= dbg_cr_wr_val[0];
		end

		wr_val <= is_call ? pc_plus_4 :
			mem_store ? op2 : alu_q;
	end
end

always @(posedge clk) begin
	if (rst) begin
		branch_taken <= 1'b0;
		stall_clear <= 1'b0;
	end else begin
		branch_taken <= instr_class == `CLASS_BRANCH &&
			(branch_condition_met || is_swi || is_rfe);
		stall_clear <= instr_class == `CLASS_BRANCH || write_cr ||
			(instr_class == `CLASS_MEM && alu_opc == `ALU_OPC_GCR);
	end
end

always @(posedge clk) begin
	if (rst) begin
		mem_load_out <= 1'b0;
		mem_store_out <= 1'b0;
		mem_wr_en <= 1'b0;
		i_valid_out <= 1'b0;
	end else begin
		mem_load_out <= mem_load;
		mem_store_out <= mem_store;

		if (mem_store || mem_load) begin
			mem_width_out <= mem_width;
			mar <= alu_q;
			if (mem_store)
				mdr <= rb;
		end

		mem_wr_en <= mem_store;
		i_valid_out <= i_valid;
	end
end

always @(posedge clk) begin
	cache_op <= op2[2:0];
	cache_instr_out <= cache_instr;
end

endmodule

