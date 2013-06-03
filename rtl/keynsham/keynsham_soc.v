module keynsham_soc(input wire clk,
		    input wire uart_rx,
		    output wire uart_tx);

wire [31:0] i_addr;
wire [31:0] i_data;
wire [31:0] d_addr;
reg [31:0] d_data;
wire [31:0] d_wr_val;
wire [3:0] d_bytesel;
wire d_wr_en;
wire d_access;

wire [31:0] ram_data;
reg [31:0] uart_data = 32'b0;

wire ram_access = d_addr[31:16] == 16'b0;
wire uart_access = d_addr[31:11] == 21'h100000;

always @(*) begin
	if (ram_access)
		d_data = ram_data;
	else if (uart_access)
		d_data = uart_data;
	else
		d_data = 32'b0;
end

reg uart_write = 1'b0;
reg [7:0] uart_din = 8'b0;
wire uart_rdy;
reg uart_rdy_clr = 1'b0;
wire [7:0] uart_dout;
wire uart_tx_busy;

uart		uart0(.clk_50m(clk),
		      .wr_en(uart_write),
		      .din(uart_din),
		      .tx(uart_tx),
		      .tx_busy(uart_tx_busy),
		      .rx(uart_rx),
		      .rdy(uart_rdy),
		      .rdy_clr(uart_rdy_clr),
		      .dout(uart_dout));

sim_dp_ram	ram(.clk(clk),
		    .i_addr(i_addr),
		    .i_data(i_data),
		    .d_cs(ram_access),
		    .d_addr(d_addr),
		    .d_data(ram_data),
		    .d_bytesel(d_bytesel),
		    .d_wr_en(d_wr_en));

oldland_cpu	cpu(.clk(clk),
		    .i_addr(i_addr),
		    .i_data(i_data),
		    .d_addr(d_addr),
		    .d_data(d_data),
		    .d_bytesel(d_bytesel),
		    .d_wr_en(d_wr_en),
		    .d_wr_val(d_wr_val),
		    .d_access(d_access));

always @(posedge clk) begin
	if (!uart_tx_busy)
		uart_write <= 1'b0;

	if (uart_access && d_wr_en) begin
		uart_din <= d_wr_val[7:0];
		uart_write <= 1'b1;
	end else if (uart_access) begin
		uart_data <= uart_tx_busy ? 32'b0 : 32'b1;
	end
end

endmodule
