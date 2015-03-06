module debug_controller(input wire		clk,
			output reg [1:0]	addr,
			output reg [31:0]	write_data,
			input wire [31:0]	read_data/*verilator public*/,
			output reg		wr_en,
			output reg		req,
			input wire		ack);

`ifdef verilator
`systemc_imp_header
void dbg_sim_term(IData val);
void start_trace();
void dbg_put(IData val);
void dbg_get(CData *req, CData *rnw, CData *addr, IData *val);
`verilog
`endif

localparam STATE_IDLE		= 4'b0001;
localparam STATE_SETUP		= 4'b0010;
localparam STATE_READ_RESULT	= 4'b0100;
localparam STATE_ISSUE_CMD	= 4'b1000;

reg		dbg_req = 1'b0;
reg		dbg_rnw = 1'b0;
reg [1:0]	dbg_addr = 2'b0;
reg [31:0]	dbg_val = 32'b0;

reg [3:0] state = STATE_IDLE;
reg [3:0] next_state = STATE_IDLE;

initial begin
	addr = 2'b00;
	write_data = 32'b0;
	wr_en = 1'b0;
	req = 1'b0;
end

task put_result;
begin
`ifdef verilator
	$c("{dbg_put(read_data);}");
`else
	$dbg_put(read_data);
`endif
end
endtask

task do_term;
begin
`ifdef verilator
	$c("{dbg_sim_term(0);}");
`else
	$dbg_sim_term(32'b0);
`endif
end
endtask

task do_start_trace;
begin
`ifdef verilator
	$c("{start_trace();}");
`endif
end
endtask

always @(*) begin
	case (state)
	STATE_IDLE: begin
		next_state = dbg_req ? STATE_SETUP : STATE_IDLE;
	end
	STATE_SETUP: begin
		if (!dbg_rnw && dbg_addr[1:0] == 2'b00)
			next_state = STATE_ISSUE_CMD;
		else if (dbg_rnw)
			next_state = STATE_READ_RESULT;
		else
			next_state = STATE_IDLE;
	end
	STATE_READ_RESULT: begin
		next_state = STATE_IDLE;
	end
	STATE_ISSUE_CMD: begin
		next_state = ack ? STATE_IDLE : STATE_ISSUE_CMD;
	end
	default: ;
	endcase
end

always @(posedge clk)
	if (state == STATE_READ_RESULT) begin
		put_result();
	end

`ifdef verilator
reg cdbg_req /*verilator public*/= 1'b0;
reg cdbg_rnw /*verilator public*/= 1'b0;
reg [1:0] cdbg_addr /*verilator public*/= 2'b0;
reg [31:0] cdbg_val/*verilator public*/ = 32'b0;

always @(posedge clk) begin
	if (state == STATE_IDLE && !ack && !dbg_req) begin
		$c("{dbg_get(&cdbg_req, &cdbg_rnw, &cdbg_addr, &cdbg_val);}");
		dbg_req <= cdbg_req;
		dbg_rnw <= cdbg_rnw;
		dbg_addr <= cdbg_addr;
		dbg_val <= cdbg_val;
	end else begin
		dbg_req <= 1'b0;
	end
end
`else
always @(posedge clk)
	if (state == STATE_IDLE && !ack && !dbg_req)
		$dbg_get(dbg_req, dbg_rnw, dbg_addr, dbg_val);
	else
		dbg_req <= 1'b0;
`endif

always @(posedge clk)
	state <= next_state;

always @(*) begin
	addr = dbg_addr;
	write_data = dbg_val;
	wr_en = (state == STATE_SETUP) & ~dbg_rnw;
end

always @(*)
	req = (state == STATE_ISSUE_CMD) && ~ack;

always @(*) begin
	if (dbg_req) begin
		/*
		 * Special hack to allow the debugger to terminate the
		 * simulation so that we can spawn a new one without
		 * worrying about system level reset.
		 */
		if (dbg_addr == 2'b00 && dbg_val == 32'hffffffff) begin
			do_term();
			$finish;
		end else if (dbg_addr == 2'b00 && dbg_val == 32'hfffffffe) begin
			do_start_trace();
		end
	end
end

endmodule
