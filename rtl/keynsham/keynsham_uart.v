module keynsham_uart(input wire		clk,
		     input wire		bus_access,
		     output wire	bus_cs,
		     input wire [29:0]	bus_addr,
		     /* verilator lint_off UNUSED */
		     input wire [31:0]	bus_wr_val,
		     /* verilator lint_on UNUSED */
		     input wire		bus_wr_en,
		     /* verilator lint_off UNUSED */
		     input wire [3:0]	bus_bytesel,
		     /* verilator lint_on UNUSED */
		     output reg		bus_error,
		     output reg		bus_ack,
		     output reg [31:0]	bus_data,
		     input wire		rx,
		     output wire	tx);

parameter	bus_address = 32'h0;
parameter	bus_size = 32'h0;

reg		uart_write = 1'b0;
reg [7:0]	uart_din = 8'b0;
wire		uart_rdy;
reg		uart_rdy_clr = 1'b0;
wire [7:0]	uart_dout;
wire		uart_tx_busy;

wire [31:0] status_reg = (uart_tx_busy ? 32'b0 : `TX_EMPTY_MASK) |
			 (uart_rdy ? `RX_READY_MASK : 32'b0);

wire            access_data_reg = {28'b0, bus_addr[1:0], 2'b0} == `UART_DATA_REG_OFFS;
wire            access_status_reg = {28'b0, bus_addr[1:0], 2'b0} == `UART_STATUS_REG_OFFS;

cs_gen		#(.address(bus_address), .size(bus_size))
		d_cs_gen(.bus_addr(bus_addr), .cs(bus_cs));

uart		uart0(.clk_50m(clk),
		      .wr_en(uart_write),
		      .din(uart_din),
		      .tx(tx),
		      .tx_busy(uart_tx_busy),
		      .rx(rx),
		      .rdy(uart_rdy),
		      .rdy_clr(uart_rdy_clr),
		      .dout(uart_dout));

initial begin
	bus_error = 1'b0;
	bus_ack = 1'b0;
	bus_data = 32'b0;
end

always @(posedge clk) begin
	bus_data <= 32'b0;

	if (!uart_tx_busy)
		uart_write <= 1'b0;
	uart_rdy_clr <= 1'b0;

	if (bus_access && bus_cs && bus_wr_en) begin
		if (access_data_reg) begin
			/* Data register write. */
			uart_din <= bus_wr_val[7:0];
			uart_write <= 1'b1;
		end
	end else if (bus_access && bus_cs) begin
		if (access_data_reg) begin
			bus_data <= {24'b0, uart_dout};
			uart_rdy_clr <= 1'b1;
		end else if (access_status_reg) begin
			/* Status register read. */
			bus_data <= status_reg;
		end
	end

	bus_ack <= bus_access && bus_cs;
end

endmodule
