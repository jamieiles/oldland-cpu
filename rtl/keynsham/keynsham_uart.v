module keynsham_uart(input wire clk,
		     input wire bus_access,
		     input wire bus_cs,
		     input wire [31:0] bus_addr,
		     input wire [31:0] bus_wr_val,
		     input wire bus_wr_en,
		     input wire [3:0] bus_bytesel,
		     output reg bus_error,
		     output reg bus_ack,
		     output reg [31:0] bus_data,
		     input wire rx,
		     output wire tx);

reg uart_write = 1'b0;
reg [7:0] uart_din = 8'b0;
wire uart_rdy;
reg uart_rdy_clr = 1'b0;
wire [7:0] uart_dout;
wire uart_tx_busy;

initial begin
	bus_error = 1'b0;
	bus_ack = 1'b0;
	bus_data = 32'b0;
end

uart		uart0(.clk_50m(clk),
		      .wr_en(uart_write),
		      .din(uart_din),
		      .tx(tx),
		      .tx_busy(uart_tx_busy),
		      .rx(rx),
		      .rdy(uart_rdy),
		      .rdy_clr(uart_rdy_clr),
		      .dout(uart_dout));

wire [31:0] status_reg = (uart_tx_busy ? 32'b0 : 32'b1) |
			 (uart_rdy ? 32'b10 : 32'b0);

always @(posedge clk) begin
	if (!uart_tx_busy)
		uart_write <= 1'b0;
	uart_rdy_clr <= 1'b0;

	if (bus_access && bus_cs && bus_wr_en) begin
		if (bus_addr[3:2] == 2'b00) begin
			/* Data register write. */
			uart_din <= bus_wr_val[7:0];
			uart_write <= 1'b1;
		end
	end else if (bus_access && bus_cs) begin
		if (bus_addr[3:2] == 2'b00) begin
			bus_data <= {24'b0, uart_dout};
			uart_rdy_clr <= 1'b1;
		end else if (bus_addr[3:2] == 2'b01) begin
			/* Status register read. */
			bus_data <= status_reg;
		end
	end

	bus_ack <= bus_access && bus_cs;
end

endmodule
