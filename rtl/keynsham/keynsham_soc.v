/* First instruction will be the boot rom at 0x10000000. */
`define OLDLAND_RESET_ADDR	32'h10000000

module keynsham_soc(input wire		clk,
		    output wire		running,
		    /* UART I/O signals. */
		    input wire		uart_rx,
		    output wire		uart_tx,
		    /* SDRAM I/O signals. */
		    output wire		s_ras_n,
		    output wire		s_cas_n,
		    output wire		s_wr_en,
		    output wire [1:0]	s_bytesel,
		    output wire [12:0]	s_addr,
		    output wire		s_cs_n,
		    output wire		s_clken,
		    inout [15:0]	s_data,
		    output wire [1:0]	s_banksel,
		    /* Debug I/O signals. */
		    input wire		dbg_clk,
		    input wire [1:0]	dbg_addr,
		    input wire [31:0]	dbg_din,
		    output wire [31:0]	dbg_dout,
		    input wire		dbg_wr_en,
		    input wire		dbg_req,
		    output wire		dbg_ack);

wire		dbg_rst;

wire [29:0]	i_addr;
wire [31:0]	i_data;
wire [29:0]	d_addr;
wire [31:0]	d_data;
wire [31:0]	d_wr_val;
wire [3:0]	d_bytesel;
wire		d_wr_en;
wire		d_access;

wire [31:0]	ram_data;
wire [31:0]	i_ram_data;
wire		ram_ack;
wire		i_ram_ack;

wire [31:0]	rom_data;
wire [31:0]	i_rom_data;
wire		rom_ack;
wire		i_rom_ack;

wire [31:0]	uart_data;
wire		uart_ack;
wire		uart_error;

wire [31:0]	timer_data;
wire		timer_ack;
wire		timer_error;
wire [3:0]	timer_irqs;

wire [31:0]	irq_data;
wire		irq_ack;
wire		irq_error;
wire		irq_req;

wire [3:0]	irqs = timer_irqs;

wire [31:0]	d_sdram_data;
wire		d_sdram_ack;
wire		d_sdram_error;
wire [31:0]	i_sdram_data;
wire		i_sdram_ack;
wire		i_sdram_error;

/*
 * For invalid addresses - ack so we don't stall the CPU on a bus access and
 * set the error bit.
 */
reg		d_default_ack = 1'b0;
reg		d_default_error = 1'b0;
reg		i_default_ack = 1'b0;
reg		i_default_error = 1'b0;

/*
 * Memory map:
 *
 * 0x00000000 -- 0x00000fff: On chip memory.
 * 0x10000000 -- 0x10000fff: Boot ROM.
 * 0x20000000 -- 0x2fffffff: SDRAM.
 * 0x80000000 -- 0x80000fff: UART0.
 * 0x80001000 -- 0x80001fff: SDRAM controller.
 * 0x80002000 -- 0x80002fff: IRQ controller.
 * 0x80003000 -- 0x80003fff: timers.
 */
wire		ram_cs;
cs_gen		#(.address(32'h00000000), .size(32'h1000))
		ram_cs_gen(.bus_addr(d_addr), .cs(ram_cs));

wire		ram_i_cs;
cs_gen		#(.address(32'h00000000), .size(32'h1000))
		ram_i_cs_gen(.bus_addr(i_addr), .cs(ram_i_cs));

wire		rom_cs;
cs_gen		#(.address(32'h10000000), .size(32'h200))
		rom_cs_gen(.bus_addr(d_addr), .cs(rom_cs));

wire		rom_i_cs;
cs_gen		#(.address(32'h10000000), .size(32'h200))
		rom_i_cs_gen(.bus_addr(i_addr), .cs(rom_i_cs));

wire		d_sdram_cs;
cs_gen		#(.address(32'h20000000), .size(32'h2000000))
		d_sdram_cs_gen(.bus_addr(d_addr), .cs(d_sdram_cs));

wire		i_sdram_cs;
cs_gen		#(.address(32'h20000000), .size(32'h2000000))
		i_sdram_cs_gen(.bus_addr(i_addr), .cs(i_sdram_cs));

wire		d_sdram_ctrl_cs;
cs_gen		#(.address(32'h80001000), .size(32'h1000))
		d_sdram_ctrl_cs_gen(.bus_addr(d_addr), .cs(d_sdram_ctrl_cs));

wire		uart_cs;
cs_gen		#(.address(32'h80000000), .size(32'h1000))
		uart_cs_gen(.bus_addr(d_addr), .cs(uart_cs));

wire		irq_cs;
cs_gen		#(.address(32'h80002000), .size(32'h1000))
		irq_cs_gen(.bus_addr(d_addr), .cs(irq_cs));

wire		timer_cs;
cs_gen		#(.address(32'h80003000), .size(32'h1000))
		timer_cs_gen(.bus_addr(d_addr), .cs(timer_cs));

wire		d_default_cs	= ~(ram_cs | rom_cs | d_sdram_cs |
				    d_sdram_ctrl_cs | uart_cs | irq_cs |
				    timer_cs);
wire		i_default_cs	= ~(ram_i_cs | rom_i_cs | i_sdram_cs);

wire		d_ack = uart_ack | ram_ack | d_sdram_ack | rom_ack | irq_ack |
			timer_ack | d_default_ack;
wire		d_error = uart_error | d_sdram_error | irq_error |
			  timer_error | d_default_error;

wire		i_access;
wire		i_ack = i_ram_ack | i_rom_ack | i_default_ack | i_sdram_ack;
wire		i_error = i_default_error | i_sdram_error;

assign		d_data	= ram_data | uart_data | d_sdram_data | rom_data |
			  irq_data | timer_data;
assign		i_data = i_ram_data | i_rom_data | i_sdram_data;

keynsham_ram	ram(.clk(clk),
		    .i_access(i_access),
		    .i_cs(ram_i_cs),
		    .i_addr(i_addr[10:0]),
		    .i_data(i_ram_data),
		    .i_ack(i_ram_ack),
		    .d_access(d_access),
		    .d_cs(ram_cs),
		    .d_addr(d_addr[10:0]),
		    .d_data(ram_data),
		    .d_bytesel(d_bytesel),
		    .d_wr_val(d_wr_val),
		    .d_wr_en(d_wr_en),
		    .d_ack(ram_ack));

keynsham_bootrom rom(.clk(clk),
		     .i_access(i_access),
		     .i_cs(rom_i_cs),
		     .i_addr(i_addr[6:0]),
		     .i_data(i_rom_data),
		     .i_ack(i_rom_ack),
		     .d_access(d_access),
		     .d_cs(rom_cs),
		     .d_addr(d_addr[6:0]),
		     .d_data(rom_data),
		     .d_bytesel(d_bytesel),
		     .d_ack(rom_ack));

keynsham_sdram	sdram(.clk(clk),
		      .ctrl_cs(d_sdram_ctrl_cs),
		      .d_access(d_access),
		      .d_cs(d_sdram_cs),
		      .d_addr(d_addr),
		      .d_wr_val(d_wr_val),
		      .d_wr_en(d_wr_en),
		      .d_bytesel(d_bytesel),
		      .d_error(d_sdram_error),
		      .d_ack(d_sdram_ack),
		      .d_data(d_sdram_data),
		      .i_access(i_access),
		      .i_cs(i_sdram_cs),
		      .i_addr(i_addr),
		      .i_error(i_sdram_error),
		      .i_ack(i_sdram_ack),
		      .i_data(i_sdram_data),
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

keynsham_irq	#(.nr_irqs(4))
		irq(.clk(clk),
		    .rst(dbg_rst),
		    .bus_access(d_access),
		    .bus_cs(irq_cs),
		    .bus_addr(d_addr),
		    .bus_wr_val(d_wr_val),
		    .bus_wr_en(d_wr_en),
		    .bus_bytesel(d_bytesel),
		    .bus_error(irq_error),
		    .bus_ack(irq_ack),
		    .bus_data(irq_data),
		    .irq_in(irqs),
		    .irq_req(irq_req));

keynsham_timer_block	timer(.clk(clk),
			      .rst(dbg_rst),
			      .bus_access(d_access),
			      .bus_cs(timer_cs),
			      .bus_addr(d_addr),
			      .bus_wr_val(d_wr_val),
			      .bus_wr_en(d_wr_en),
			      .bus_bytesel(d_bytesel),
			      .bus_error(timer_error),
			      .bus_ack(timer_ack),
			      .bus_data(timer_data),
			      .irqs(timer_irqs));

oldland_cpu	cpu(.clk(clk),
		    .running(running),
		    .irq_req(irq_req),
		    .i_access(i_access),
		    .i_addr(i_addr),
		    .i_data(i_data),
		    .i_ack(i_ack),
		    .i_error(i_error),
		    .d_addr(d_addr),
		    .d_data(d_data),
		    .d_bytesel(d_bytesel),
		    .d_wr_en(d_wr_en),
		    .d_wr_val(d_wr_val),
		    .d_access(d_access),
		    .d_ack(d_ack),
		    .d_error(d_error),
		    .dbg_clk(dbg_clk),
		    .dbg_addr(dbg_addr),
		    .dbg_din(dbg_din),
		    .dbg_dout(dbg_dout),
		    .dbg_wr_en(dbg_wr_en),
		    .dbg_req(dbg_req),
		    .dbg_ack(dbg_ack),
		    .dbg_rst(dbg_rst));

always @(posedge clk) begin
	d_default_ack <= d_access && d_default_cs;
	d_default_error <= d_access && d_default_cs;

	i_default_ack <= i_access && i_default_cs;
	i_default_error <= i_access && i_default_cs;
end

endmodule
