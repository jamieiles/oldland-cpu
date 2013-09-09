module debug_controller(input wire		clk,
			output reg [1:0]	addr,
			output reg [31:0]	write_data,
			input wire [31:0]	read_data,
			output reg		wr_en,
			output reg		req,
			input wire		ack);

reg [31:0]	nr_steps = 32'b0;

reg		dbg_req = 1'b0;
reg		dbg_rnw = 1'b0;
reg [1:0]	dbg_addr = 2'b0;
reg [31:0]	dbg_val = 32'b0;

initial begin
	addr = 2'b00;
	write_data = 32'b0;
	wr_en = 1'b0;
	req = 1'b0;
end

always @(posedge clk) begin
	if (!req && !ack) begin
		$dbg_get(dbg_req, dbg_rnw, dbg_addr, dbg_val);

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

			addr <= dbg_addr;
			write_data <= dbg_val;
			wr_en <= ~dbg_rnw;
			req <= dbg_addr[1:0] == 2'b00;

			/*
			 * Wait for the read data to be presented at the read
			 * port.
			 */
			if (dbg_rnw) begin
				@(posedge clk);
				@(posedge clk);
				$dbg_put(read_data);
			end
		end
	end else if (ack) begin
		wr_en <= 1'b0;
		req <= 1'b0;
	end
end

endmodule
