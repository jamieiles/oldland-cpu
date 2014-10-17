module oldland_debug(input wire		clk,
		     input wire		dbg_clk,
		     input wire [1:0]	addr,
		     input wire [31:0]	din,
		     output wire [31:0]	dout,
		     input wire		wr_en,
		     input wire		req,
		     output wire	ack,
		     output reg		dbg_en,
		     /* External reset request. */
		     input wire		rst_req_in,
		     /* Execution control signals. */
		     output wire	run,
		     input wire		stopped,
                     input wire         bkpt_hit,
		     /* Memory read/write signals. */
		     output wire [31:0] mem_addr,
		     output reg [1:0]	mem_width,
		     output wire [31:0] mem_wr_val,
		     input wire [31:0]	mem_rd_val,
		     output reg		mem_wr_en,
		     output reg		mem_access,
		     input wire		mem_compl,
		     /* GPR read/write signals. */
		     output wire [3:0]	dbg_reg_sel,
		     input wire [31:0]	dbg_reg_val,
		     output wire [31:0]	dbg_reg_wr_val,
		     output reg		dbg_reg_wr_en,
		     /* Control register signals. */
		     output wire [2:0]	dbg_cr_sel,
		     input wire [31:0]	dbg_cr_val,
		     output wire [31:0]	dbg_cr_wr_val,
		     output reg		dbg_cr_wr_en,
		     /* PC read/write signals. */
		     input wire [31:0]	dbg_pc,
		     output reg		dbg_pc_wr_en,
		     output wire [31:0]	dbg_pc_wr_val,
		     /* Reset control. */
		     output wire	dbg_rst,
		     /* Cache maintenance. */
		     output reg	[icache_idx_bits - 1:0] dbg_icache_idx,
		     output reg [dcache_idx_bits - 1:0] dbg_dcache_idx,
		     output wire	dbg_icache_inval,
		     output wire	dbg_dcache_inval,
		     output wire	dbg_dcache_flush,
		     input wire		dbg_icache_complete,
		     input wire		dbg_dcache_complete,
		     /* CPUID. */
		     output wire [2:0]	cpuid_sel,
		     input wire [31:0]	cpuid_val);

parameter icache_nr_lines	= 0;
parameter dcache_nr_lines	= 0;

localparam icache_idx_bits	= $clog2(icache_nr_lines);
localparam dcache_idx_bits	= $clog2(dcache_nr_lines);

localparam STATE_IDLE		= 18'b000000000000000001;
localparam STATE_LOAD_CMD	= 18'b000000000000000010;
localparam STATE_LOAD_ADDR	= 18'b000000000000000100;
localparam STATE_LOAD_DATA	= 18'b000000000000001000;
localparam STATE_WAIT_STOPPED	= 18'b000000000000010000;
localparam STATE_STEP		= 18'b000000000000100000;
localparam STATE_COMPL		= 18'b000000000001000000;
localparam STATE_STORE_REG_RVAL	= 18'b000000000010000000;
localparam STATE_WRITE_REG	= 18'b000000000100000000;
localparam STATE_WAIT_RMEM	= 18'b000000001000000000;
localparam STATE_WAIT_WMEM	= 18'b000000010000000000;
localparam STATE_EXECUTE	= 18'b000000100000000000;
localparam STATE_RESET		= 18'b000001000000000000;
localparam STATE_CACHE_FLUSH	= 18'b000010000000000000;
localparam STATE_CACHE_INVAL	= 18'b000100000000000000;
localparam STATE_EXT_RESET_STOP = 18'b001000000000000000;
localparam STATE_EXT_RESET_RESET= 18'b010000000000000000;
localparam STATE_EXT_RESET_START= 18'b100000000000000000;

localparam CMD_HALT		= 4'h0;
localparam CMD_RUN		= 4'h1;
localparam CMD_STEP		= 4'h2;
localparam CMD_READ_REG		= 4'h3;
localparam CMD_WRITE_REG	= 4'h4;
localparam CMD_RMEM32		= 4'h5;
localparam CMD_RMEM16		= 4'h6;
localparam CMD_RMEM8		= 4'h7;
localparam CMD_WMEM32		= 4'h8;
localparam CMD_WMEM16		= 4'h9;
localparam CMD_WMEM8		= 4'ha;
localparam CMD_RESET            = 4'hb;
localparam CMD_CACHE_SYNC	= 4'hc;
localparam CMD_CPUID		= 4'hd;
localparam CMD_GET_EXEC_STATUS	= 4'he;

reg [1:0]	ctl_addr = 2'b00;
reg [31:0]	ctl_din = 32'b0;
wire [31:0]	ctl_dout;
reg		ctl_wr_en = 1'b0;

reg [17:0]	state = STATE_IDLE;
reg [17:0]	next_state = STATE_IDLE;

reg [3:0]	debug_cmd = 4'b0;
reg [31:0]	debug_addr = 32'b0;
reg [31:0]	debug_data = 32'b0;

reg [11:0]	reset_count = 12'hfff;

wire		req_sync;	/*
				 * Synchronized from debug to CPU clock.
				 */
reg		ack_internal;	/*
				 * CPU clock, will be synchronized to debug
				 * clock.
				 */
reg		do_run = 1'b1;
reg		stopped_on_bkpt = 1'b0;
assign		run = do_run && !bkpt_hit;

assign		dbg_reg_sel = debug_addr[3:0];
assign		dbg_pc_wr_val = debug_data;
assign		dbg_reg_wr_val = debug_data;
assign		mem_addr = debug_addr;
assign		mem_wr_val = debug_data;
assign		dbg_rst = state == STATE_RESET || state == STATE_EXT_RESET_RESET;
assign		dbg_cr_sel = debug_addr[2:0];
assign		dbg_cr_wr_val = debug_data;
assign		dbg_icache_inval = state == STATE_CACHE_INVAL & ~dbg_icache_complete | dbg_rst;
assign		dbg_dcache_inval = state == STATE_CACHE_INVAL & ~dbg_dcache_complete | dbg_rst;
assign		dbg_dcache_flush = state == STATE_CACHE_FLUSH & ~dbg_dcache_complete;
assign		cpuid_sel = debug_addr[2:0];

dc_ram		#(.addr_bits(2),
		  .data_bits(32))
		dbg_ram(.clk_a(dbg_clk),
			.addr_a(addr),
			.din_a(din),
			.dout_a(dout),
			.wr_en_a(wr_en),
			.clk_b(clk),
			.addr_b(ctl_addr),
			.din_b(ctl_din),
			.dout_b(ctl_dout),
			.wr_en_b(ctl_wr_en));

sync2ff		sync_req(.dst_clk(clk),
			 .din(req),
			 .dout(req_sync));

sync2ff		sync_ack(.dst_clk(dbg_clk),
			 .din(ack_internal),
			 .dout(ack));

initial begin
	ack_internal = 1'b0;
	dbg_reg_wr_en = 1'b0;
	dbg_pc_wr_en = 1'b0;
	dbg_cr_wr_en = 1'b0;
	mem_wr_en = 1'b0;
	mem_access = 1'b0;
	dbg_icache_idx = {icache_idx_bits{1'b0}};
	dbg_dcache_idx = {dcache_idx_bits{1'b0}};
	dbg_en = 1'b0;
end

always @(*) begin
	mem_wr_en = 1'b0;

	case (debug_cmd)
	CMD_WMEM32: begin
		mem_width = 2'b10;
		mem_wr_en = 1'b1;
	end
	CMD_WMEM16: begin
		mem_width = 2'b01;
		mem_wr_en = 1'b1;
	end
	CMD_WMEM8: begin
		mem_width = 2'b00;
		mem_wr_en = 1'b1;
	end
	CMD_RMEM32: mem_width = 2'b10;
	CMD_RMEM16: mem_width = 2'b01;
	CMD_RMEM8: mem_width = 2'b00;
	default: begin
		mem_width = 2'b10;
		mem_wr_en = 1'b0;
	end
	endcase
end

always @(*) begin
	ctl_din = 32'b0;
	ctl_addr = 2'b00;
	ctl_wr_en = 1'b0;
	dbg_pc_wr_en = 1'b0;
	dbg_cr_wr_en = 1'b0;
	dbg_reg_wr_en = 1'b0;
	mem_access = 1'b0;

	case (state)
	STATE_IDLE: begin
		if (rst_req_in)
			next_state = STATE_EXT_RESET_STOP;
		else
			next_state = req_sync ? STATE_LOAD_CMD : STATE_IDLE;
		ctl_addr = 2'b00;
	end
	STATE_LOAD_CMD: begin
		next_state = STATE_LOAD_ADDR;
		ctl_addr = 2'b01;
	end
	STATE_LOAD_ADDR: begin
		next_state = STATE_LOAD_DATA;
		ctl_addr = 2'b10;
	end
	STATE_LOAD_DATA: begin
		next_state = STATE_EXECUTE;
	end
	STATE_EXECUTE: begin
		case (debug_cmd)
		CMD_HALT: next_state = STATE_WAIT_STOPPED;
		CMD_RUN: next_state = STATE_COMPL;
		CMD_STEP: next_state = STATE_STEP;
		CMD_READ_REG: begin
			next_state = STATE_STORE_REG_RVAL;
		end
		CMD_WRITE_REG: begin
			next_state = STATE_WRITE_REG;
		end
		CMD_RMEM8: begin
			next_state = STATE_WAIT_RMEM;
			mem_access = 1'b1;
		end
		CMD_RMEM16: begin
			next_state = STATE_WAIT_RMEM;
			mem_access = 1'b1;
		end
		CMD_RMEM32: begin
			next_state = STATE_WAIT_RMEM;
			mem_access = 1'b1;
		end
		CMD_WMEM8: begin
			next_state = STATE_WAIT_WMEM;
			mem_access = 1'b1;
		end
		CMD_WMEM16: begin
			next_state = STATE_WAIT_WMEM;
			mem_access = 1'b1;
		end
		CMD_WMEM32: begin
			next_state = STATE_WAIT_WMEM;
			mem_access = 1'b1;
		end
		CMD_RESET: begin
			next_state = STATE_RESET;
		end
		CMD_CACHE_SYNC: begin
			next_state = STATE_CACHE_FLUSH;
		end
		CMD_CPUID: begin
			next_state = STATE_COMPL;
			ctl_addr = 2'b11;
			ctl_wr_en = 1'b1;
			ctl_din = cpuid_val;
		end
		CMD_GET_EXEC_STATUS: begin
			next_state = STATE_COMPL;
			ctl_addr = 2'b11;
			ctl_wr_en = 1'b1;
			ctl_din = {30'b0, stopped_on_bkpt, run};
		end
		default: next_state = STATE_COMPL;
		endcase
	end
	STATE_RESET: begin
		next_state = |reset_count ? STATE_RESET : STATE_COMPL;
	end
	STATE_EXT_RESET_RESET: begin
		next_state = |reset_count ?
			STATE_EXT_RESET_RESET : STATE_EXT_RESET_START;
	end
	STATE_EXT_RESET_START: begin
		next_state = STATE_IDLE;
	end
	STATE_CACHE_FLUSH: begin
		next_state = dbg_dcache_idx == {dcache_idx_bits{1'b1}} ?
			STATE_CACHE_INVAL : STATE_CACHE_FLUSH;
	end
	STATE_CACHE_INVAL: begin
		next_state = dbg_icache_idx == {icache_idx_bits{1'b1}} ?
			STATE_COMPL : STATE_CACHE_INVAL;
	end
	STATE_WRITE_REG: begin
		if (debug_addr[4])
			dbg_pc_wr_en = 1'b1;
		else if (debug_addr[5])
			dbg_cr_wr_en = 1'b1;
		else
			dbg_reg_wr_en = 1'b1;
		next_state = STATE_COMPL;
	end
	STATE_WAIT_WMEM: begin
		next_state = mem_compl ? STATE_COMPL : STATE_WAIT_WMEM;
	end
	STATE_WAIT_RMEM: begin
		if (mem_compl) begin
			ctl_addr = 2'b11;
			ctl_wr_en = 1'b1;
			ctl_din = mem_rd_val;
			next_state = STATE_COMPL;
		end else begin
			next_state = STATE_WAIT_RMEM;
		end
	end
	STATE_STEP: begin
		next_state = STATE_WAIT_STOPPED;
	end
	STATE_WAIT_STOPPED: begin
		next_state = stopped ? STATE_COMPL : STATE_WAIT_STOPPED;
		if (stopped) begin
			ctl_addr = 2'b11;
			ctl_wr_en = 1'b1;
			ctl_din = dbg_pc;
		end
	end
	STATE_EXT_RESET_STOP: begin
		next_state = stopped ? STATE_EXT_RESET_RESET :
			STATE_EXT_RESET_STOP;
	end
	STATE_STORE_REG_RVAL: begin
		ctl_addr = 2'b11;
		ctl_wr_en = 1'b1;
		ctl_din = debug_addr[4] ? dbg_pc :
			  debug_addr[5] ? dbg_cr_val : dbg_reg_val;
		next_state = STATE_COMPL;
	end
	STATE_COMPL: begin
		next_state = req_sync ? STATE_COMPL : STATE_IDLE;
	end
	default: begin
		next_state = STATE_IDLE;
	end
	endcase
end

always @(posedge clk) begin
	ack_internal <= 1'b0;

	if (do_run && bkpt_hit)
		do_run <= 1'b0;

	case (state)
	STATE_IDLE: begin
	end
	STATE_LOAD_CMD: begin
		debug_cmd <= ctl_dout[3:0];
	end
	STATE_LOAD_ADDR: begin
		debug_addr <= ctl_dout;

		case (debug_cmd)
		CMD_READ_REG: dbg_en <= 1'b1;
		CMD_WRITE_REG: dbg_en <= 1'b1;
		CMD_RMEM8: dbg_en <= 1'b1;
		CMD_RMEM16: dbg_en <= 1'b1;
		CMD_RMEM32: dbg_en <= 1'b1;
		CMD_WMEM8: dbg_en <= 1'b1;
		CMD_WMEM16: dbg_en <= 1'b1;
		CMD_WMEM32: dbg_en <= 1'b1;
		CMD_RESET: dbg_en <= 1'b1;
		CMD_CPUID: dbg_en <= 1'b1;
		CMD_CACHE_SYNC: dbg_en <= 1'b1;
		default: dbg_en <= 1'b0;
		endcase
	end
	STATE_LOAD_DATA: begin
		debug_data <= ctl_dout;
	end
	STATE_EXECUTE: begin
		reset_count <= 12'hfff;

		case (debug_cmd)
		CMD_HALT: do_run <= 1'b0;
		CMD_RUN: do_run <= 1'b1;
		CMD_STEP: do_run <= 1'b1;
		CMD_RESET: do_run <= 1'b0;
		default: begin
		end
		endcase
	end
	STATE_EXT_RESET_STOP: begin
		reset_count <= 12'hfff;
		do_run <= 1'b0;
	end
	STATE_RESET, STATE_EXT_RESET_RESET: begin
		if (|reset_count) begin
			reset_count <= reset_count - 12'b1;
			dbg_icache_idx <= dbg_icache_idx + 1'b1;
			dbg_dcache_idx <= dbg_dcache_idx + 1'b1;
		end else begin
			dbg_icache_idx <= {icache_idx_bits{1'b0}};
			dbg_dcache_idx <= {dcache_idx_bits{1'b0}};
		end
	end
	STATE_STEP: begin
		do_run <= 1'b0;
	end
	STATE_EXT_RESET_START: begin
		do_run <= 1'b1;
	end
	STATE_CACHE_FLUSH: begin
		dbg_dcache_idx <= dbg_dcache_complete ? dbg_dcache_idx + 1'b1 :
			dbg_dcache_idx;
	end
	STATE_CACHE_INVAL: begin
		dbg_icache_idx <= dbg_icache_idx + 1'b1;
		dbg_dcache_idx <= dbg_dcache_idx + 1'b1;
	end
	STATE_COMPL: begin
		ack_internal <= 1'b1;
                dbg_icache_idx <= {icache_idx_bits{1'b0}};
                dbg_dcache_idx <= {dcache_idx_bits{1'b0}};
		dbg_en <= 1'b0;
	end
	default: begin
	end
	endcase
end

always @(posedge clk)
	if (bkpt_hit)
		stopped_on_bkpt <= 1'b1;
	else if (stopped_on_bkpt && run)
		stopped_on_bkpt <= 1'b0;

always @(posedge clk)
	state <= next_state;

endmodule
