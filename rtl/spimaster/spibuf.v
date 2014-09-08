module spibuf(input wire			clk,
	      /* Host port. */
	      input wire [addr_bits - 1:0]	a_addr,
	      input wire [7:0]			a_wr_val,
	      output reg [7:0]			a_rd_val,
	      input wire			a_wr_en,
	      /* SPI port. */
	      input wire [addr_bits - 1:0]	b_addr,
	      input wire [7:0]			b_wr_val,
	      output reg [7:0]			b_rd_val,
	      input wire			b_wr_en);

parameter	num_bytes = 8192;

localparam	addr_bits = $clog2(num_bytes);

reg [7:0]	mem[num_bytes - 1:0];

integer		i;

initial begin
	for (i = 0; i < num_bytes; i = i + 1)
		mem[i] = 8'h00;
	a_rd_val = 8'b0;
	b_rd_val = 8'b0;
end

always @(posedge clk) begin
	if (a_wr_en) begin
		mem[a_addr] <= a_wr_val;
		a_rd_val <= a_wr_val;
	end else begin
		a_rd_val <= mem[a_addr];
	end
end

always @(posedge clk) begin
	if (b_wr_en) begin
		mem[b_addr] <= b_wr_val;
		b_rd_val <= b_wr_val;
	end else begin
		b_rd_val <= mem[b_addr];
	end
end

endmodule
