/* First instruction will be the boot rom at 0x10000000. */
`define OLDLAND_RESET_ADDR	32'h0ffffffc

module keynsham_soc(input wire clk,
		    input wire uart_rx,
		    output wire uart_tx,
		    output wire s_ras_n,
		    output wire s_cas_n,
		    output wire s_wr_en,
		    output wire [1:0] s_bytesel,
		    output wire [12:0] s_addr,
		    output wire s_cs_n,
		    output wire s_clken,
		    inout [15:0] s_data,
		    output wire [1:0] s_banksel);

wire [31:0] i_addr;
reg [31:0] i_data = 32'b0;
wire [31:0] d_addr;
reg [31:0] d_data = 32'b0;
wire [31:0] d_wr_val;
wire [3:0] d_bytesel;
wire d_wr_en;
wire d_access;

wire [31:0] ram_data;
wire [31:0] i_ram_data;
wire ram_ack;

wire [31:0] rom_data;
wire [31:0] i_rom_data;
wire rom_ack;

wire [31:0] uart_data;
wire uart_ack;
wire uart_error;

wire [31:0] sdram_data;
wire sdram_ack;
wire sdram_error;

/*
 * Memory map:
 *
 * 0x00000000 -- 0x00000fff: On chip memory.
 * 0x10000000 -- 0x10000fff: Boot ROM.
 * 0x20000000 -- 0x2fffffff: SDRAM.
 * 0x80000000 -- 0x80000fff: UART0.
 * 0x80001000 -- 0x80001fff: SDRAM controller.
 */
wire ram_cs		= d_addr[31:12]	== 20'h00000;
wire ram_i_cs		= i_addr[31:12]	== 20'h00000;
wire rom_cs		= d_addr[31:12]	== 20'h10000;
wire rom_i_cs		= i_addr[31:12]	== 20'h10000;
wire sdram_cs		= d_addr[31:25] == 7'b0010000;
wire sdram_ctrl_cs	= d_addr[31:12] == 20'h80001;
wire uart_cs		= d_addr[31:12] == 20'h80000;

always @(*) begin
	if (ram_cs)
		d_data = ram_data;
	else if (uart_cs)
		d_data = uart_data;
	else if (sdram_cs || sdram_ctrl_cs)
		d_data = sdram_data;
	else if (rom_cs)
		d_data = rom_data;
	else
		d_data = 32'b0;
end

always @(*) begin
	if (ram_i_cs)
		i_data = i_ram_data;
	else if (rom_i_cs)
		i_data = i_rom_data;
	else
		i_data = 32'b0;
end

wire d_ack = uart_ack | ram_ack | sdram_ack | rom_ack;
wire d_error = uart_error | sdram_error;

keynsham_ram	ram(.clk(clk),
		    .i_addr(i_addr),
		    .i_data(i_ram_data),
		    .d_access(d_access),
		    .d_cs(ram_cs),
		    .d_addr(d_addr),
		    .d_data(ram_data),
		    .d_bytesel(d_bytesel),
		    .d_wr_val(d_wr_val),
		    .d_wr_en(d_wr_en),
		    .d_ack(ram_ack));

keynsham_bootrom rom(.clk(clk),
		     .i_addr(i_addr),
		     .i_data(i_rom_data),
		     .d_access(d_access),
		     .d_cs(rom_cs),
		     .d_addr(d_addr),
		     .d_data(rom_data),
		     .d_bytesel(d_bytesel),
		     .d_ack(rom_ack));

keynsham_sdram	sdram(.clk(clk),
		      .bus_access(d_access),
		      .sdram_cs(sdram_cs),
		      .ctrl_cs(sdram_ctrl_cs),
		      .bus_addr(d_addr),
		      .bus_wr_val(d_wr_val),
		      .bus_wr_en(d_wr_en),
		      .bus_bytesel(d_bytesel),
		      .bus_error(sdram_error),
		      .bus_ack(sdram_ack),
		      .bus_data(sdram_data),
		      .s_ras_n(s_ras_n),
		      .s_cas_n(s_cas_n),
		      .s_wr_en(s_wr_en),
		      .s_bytesel(s_bytesel),
		      .s_addr(s_addr),
		      .s_cs_n(s_cs_n),
		      .s_clken(s_clken),
		      .s_data(s_data),
		      .s_banksel(s_banksel));

keynsham_uart	uart(.clk(clk),
		     .bus_access(d_access),
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
