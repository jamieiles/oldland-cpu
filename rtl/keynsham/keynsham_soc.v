module keynsham_soc(input wire clk,
		    input wire uart_rx,
		    output wire uart_tx);

wire [31:0] i_addr;
wire [31:0] i_data;
wire [31:0] d_addr;
reg [31:0] d_data = 32'b0;
wire [31:0] d_wr_val;
wire [3:0] d_bytesel;
wire d_wr_en;
wire d_access;

wire [31:0] ram_data;
wire [31:0] uart_data;

wire uart_ack;
wire uart_error;

/*
 * Memory map:
 *
 * 0x00000000 -- 0x00000fff: On chip memory.
 * 0x80000000 -- 0x80000fff: UART0.
 */
wire ram_cs	= d_addr[31:13] == 19'b0000000000000000000;
wire uart_cs	= d_addr[31:13] == 19'b1000000000000000000;

always @(*) begin
	if (ram_cs)
		d_data = ram_data;
	else if (uart_cs)
		d_data = uart_data;
	else
		d_data = 32'b0;
end

wire d_ack = uart_ack;
wire d_error = uart_error;

sim_dp_ram	ram(.clk(clk),
		    .i_addr(i_addr),
		    .i_data(i_data),
		    .d_cs(ram_cs),
		    .d_addr(d_addr),
		    .d_data(ram_data),
		    .d_bytesel(d_bytesel),
		    .d_wr_val(d_wr_val),
		    .d_wr_en(d_wr_en));

keynsham_uart	uart(.clk(clk),
		     .bus_cs(uart_cs),
		     .bus_addr(d_addr),
		     .bus_wr_val(d_wr_val),
		     .bus_wr_en(d_wr_en),
		     .bus_bytesel(d_bytesel),
		     .bus_error(uart_error),
		     .bus_ack(uart_ack),
		     .bus_data(uart_data),
		     .rx(uart_rx),
		     .tx(uart_tx));

oldland_cpu	cpu(.clk(clk),
		    .i_addr(i_addr),
		    .i_data(i_data),
		    .d_addr(d_addr),
		    .d_data(d_data),
		    .d_bytesel(d_bytesel),
		    .d_wr_en(d_wr_en),
		    .d_wr_val(d_wr_val),
		    .d_access(d_access),
		    .d_ack(d_ack),
		    .d_error(d_error));

endmodule
