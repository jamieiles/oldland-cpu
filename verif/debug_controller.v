module debug_controller(input wire		clk,
			output reg [1:0]	addr,
			output reg [31:0]	write_data,
			input wire [31:0]	read_data,
			output reg		wr_en,
			output reg		req,
			input wire		ack);

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
	STATE_IDLE: begin
		next_state = STATE_IDLE;
	end
	endcase
end

always @(posedge clk)
	if (state == STATE_READ_RESULT)
		$dbg_put(read_data);

always @(posedge clk)
	if (state == STATE_IDLE)
		$dbg_get(dbg_req, dbg_rnw, dbg_addr, dbg_val);

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
			$dbg_sim_term(32'b0);
			$finish;
		end
	end
end

endmodule
