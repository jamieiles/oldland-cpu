module debug_controller(input wire		clk,
			output reg [1:0]	addr,
			output reg [31:0]	write_data,
			input wire [31:0]	read_data,
			output reg		wr_en,
			output reg		req,
			input wire		ack);

initial begin
	addr = 2'b00;
	write_data = 32'b0;
	wr_en = 1'b0;
	req = 1'b0;
end

reg [31:0] nr_steps = 32'b0;

always @(posedge clk) begin
	if (nr_steps < 32'd32) begin
		addr <= 2'b00;
		wr_en <= 1'b1;
		write_data <= 32'h3;

		@(posedge clk);
		addr <= 2'b01;
		write_data <= 32'h8; /* PC */

		@(posedge clk);
		wr_en <= 1'b0;
		req <= 1'b1;


		@(posedge clk);
		@(posedge ack);
		@(posedge clk);
		req <= 1'b0;
		addr <= 2'b11;
		@(negedge ack);
		@(posedge clk);

		@(posedge clk);
		$display("pc: %x", read_data);
	end

	if (nr_steps <= 32'd500) begin
		/* Step the CPU then wait for 50 cycles. */
		addr <= 2'b00;
		wr_en <= 1'b1;
		write_data <= nr_steps == 32'd500 ? 32'h1 : 32'h2;	/* CMD_RUN : CMD_STEP */

		@(posedge clk);
		wr_en <= 1'b0;

		#10;
		@(posedge clk);
		req <= 1'b1;	/* Start the operation. */

		@(posedge ack);
		@(posedge clk);
		req <= 1'b0;
		@(negedge ack);	/* Wait for completion. */
		@(posedge clk);

		#500;

		nr_steps <= nr_steps + 32'b1;
	end
end

endmodule
