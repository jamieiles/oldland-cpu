`ifndef OLDLAND_ROM_PATH
`define OLDLAND_ROM_PATH "./"
`endif

/*
 * Generate a variety of control signals from the input selection.  These
 * control signals include register selection, ALU opcode + operand selection
 * and load/store signals.
 */
module oldland_decode(input wire	clk,
		      input wire	rst,
		      input wire [31:0] instr,
		      output wire [3:0] ra_sel,
		      output wire [3:0] rb_sel,
		      output reg [3:0]	rd_sel,
		      output reg	update_rd,
		      output reg [31:0] imm32,
		      output reg [4:0]	alu_opc,
		      output reg [3:0]	branch_condition,
		      output reg	alu_op1_ra,
		      output reg	alu_op1_rb,
		      output reg	alu_op2_rb,
		      output reg	mem_load,
		      output reg	mem_store,
		      output reg [1:0]	mem_width,
		      input wire [31:0] pc_plus_4,
		      output reg [31:0] pc_plus_4_out,
		      output reg [1:0]	instr_class,
		      output reg	is_call,
		      output reg	update_flags,
		      output reg	update_carry,
                      output reg [2:0]  cr_sel,
                      output reg        write_cr,
                      output reg        spsr,
                      output reg        is_swi,
		      output reg	is_rfe,
		      output wire	illegal_instr,
		      output reg	exception_start_out,
		      input wire	i_fetched,
		      output reg	i_valid,
		      output wire	bkpt_hit,
		      output reg	cache_instr,
		      input wire	user_mode);

wire [6:0]      addr = instr[31:25];

reg [31:0]      microcode[127:0];
wire [29:0]     uc_val = microcode[addr][29:0];

wire            valid = uc_val[22] & ~(privileged & user_mode);
wire [1:0]      imsel = uc_val[21:20];
wire            rd_is_lr = uc_val[12];

wire [31:0]     imm13 = {{19{instr[24]}}, instr[24:12]};
wire [31:0]     imm24 = {{6{instr[23]}}, instr[23:0], 2'b00};
wire [31:0]     hi16 = {instr[25:10], 16'b0};
wire [31:0]     lo16 = {16'b0, instr[25:10]};

assign		ra_sel = instr[11:8];
assign		rb_sel = instr[7:4];

wire		privileged = uc_val[28];
assign		illegal_instr = ~valid;

assign		bkpt_hit = instr[31:30] == `CLASS_MISC &&
			   instr[29:25] == {`OPCODE_BKP, 1'b0};

initial begin
	$readmemh({`OLDLAND_ROM_PATH, "decode.hex"}, microcode, 0, 127);
	rd_sel = 4'b0;
	update_rd = 1'b0;
	alu_opc = 5'b0;
	branch_condition = 4'b0;
	alu_op1_ra = 1'b0;
	alu_op1_rb = 1'b0;
	alu_op2_rb = 1'b0;
	mem_load = 1'b0;
	mem_store = 1'b0;
	mem_width = 2'b0;
	pc_plus_4_out = 32'b0;
	instr_class = 2'b0;
	is_call = 1'b0;
	update_flags = 1'b0;
	update_carry = 1'b0;
        cr_sel = 3'b0;
        write_cr = 1'b0;
        spsr = 1'b0;
        is_swi = 1'b0;
	is_rfe = 1'b0;
	i_valid = 1'b0;
	cache_instr = 1'b0;
	exception_start_out = 1'b0;
end

always @(posedge clk) begin
	if (rst || !valid) begin
		/*
		 * Reset is only concerned with anything that can affect
		 * state.
		 */
		is_rfe <= 1'b0;
		is_swi <= 1'b0;
		write_cr <= 1'b0;
		spsr <= 1'b0;
		is_call <= 1'b0;
		mem_store <= 1'b0;
		mem_load <= 1'b0;
		update_flags <= 1'b0;
		update_carry <= 1'b0;
		update_rd <= 1'b0;
		instr_class <= 2'b00;
		i_valid <= 1'b0;
		cache_instr <= 1'b0;
	end else begin
                spsr <= uc_val[29];
		cache_instr <= uc_val[27];
		update_carry <= uc_val[26];
		is_rfe <= uc_val[25];
		is_swi <= uc_val[24];
		write_cr <= uc_val[23];
		branch_condition <= uc_val[19:16];
		mem_width <= uc_val[15:14];
		is_call <= uc_val[13];
		mem_store <= uc_val[11];
		mem_load <= uc_val[10];
		alu_op2_rb <= uc_val[9];
		alu_op1_rb <= uc_val[8];
		alu_op1_ra <= uc_val[7];
		update_flags <= uc_val[6];
		update_rd <= uc_val[5];
		alu_opc <= uc_val[4:0];

		instr_class <= instr[31:30];
		cr_sel <= instr[14:12];
		i_valid <= valid && i_fetched;
	end
end

always @(posedge clk)
	rd_sel <= rd_is_lr ? 4'hf : instr[3:0];

always @(posedge clk) begin
	case (imsel)
	2'b00: imm32 <= imm13;
	2'b01: imm32 <= imm24;
	2'b10: imm32 <= hi16;
	2'b11: imm32 <= lo16;
	endcase
end

always @(posedge clk)
	pc_plus_4_out <= rst ? 32'b0 : pc_plus_4;

always @(posedge clk)
	exception_start_out <= illegal_instr | uc_val[24];

endmodule
