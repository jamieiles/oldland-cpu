/* First instruction will be the boot rom at 0x10000000. */
`define OLDLAND_RESET_ADDR	32'h10000000

`ifdef USE_DEBUG_UART
`define CONFIG_UART simuart
`else
`define CONFIG_UART keynsham_uart
`endif

module keynsham_soc(input wire		clk,
		    output wire		running,
		    input wire		rst_req,
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
		    output wire		dbg_ack,
`ifdef GPIO_ADDRESS
		    inout wire [63:0]	gpio,
`endif
		    /* SPI bus. */
		    input wire		miso,
		    output wire		mosi,
		    output wire		sclk,
                    output wire [spi_num_cs - 1:0] spi_ncs);

parameter       spi_num_cs = 2;

wire		dbg_rst;

wire [29:0]	i_addr;
wire [31:0]	i_data;
wire [29:0]	d_addr;
wire [31:0]	d_data;
wire [31:0]	d_wr_val = d_wr_en ? cpu_d_out : 32'b0;
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

wire [31:0]	spimaster_data;
wire		spimaster_ack;
wire		spimaster_error;

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

wire [31:0]     gpio_data;
wire            gpio_ack;
wire            gpio_error;

wire [31:0]	cpu_d_out;

/*
 * For invalid addresses - ack so we don't stall the CPU on a bus access and
 * set the error bit.
 */
reg		d_default_ack = 1'b0;
reg		d_default_error = 1'b0;
reg		i_default_ack = 1'b0;
reg		i_default_error = 1'b0;

wire		ram_cs;
wire		ram_i_cs;
wire		rom_cs;
wire		rom_i_cs;
wire		d_sdram_cs;
wire		i_sdram_cs;
wire		d_sdram_ctrl_cs;
wire		uart_cs;
wire		irq_cs;
wire		timer_cs;
wire		spimaster_cs;
wire		gpio_cs;

wire		d_default_cs	= ~(ram_cs | rom_cs | d_sdram_cs |
				    d_sdram_ctrl_cs | uart_cs | irq_cs |
				    timer_cs | spimaster_cs | gpio_cs);
wire		i_default_cs	= ~(ram_i_cs | rom_i_cs | i_sdram_cs);

wire		d_ack = uart_ack | ram_ack | d_sdram_ack | rom_ack | irq_ack |
			timer_ack | d_default_ack | spimaster_ack | gpio_ack;
wire		d_error = uart_error | d_sdram_error | irq_error |
			  timer_error | d_default_error | spimaster_error |
			  gpio_error;

wire		i_access;
wire		i_ack = i_ram_ack | i_rom_ack | i_default_ack | i_sdram_ack;
wire		i_error = i_default_error | i_sdram_error;

assign		d_data	= ram_data | uart_data | d_sdram_data | rom_data |
			  irq_data | timer_data | d_wr_val | spimaster_data |
			  gpio_data;
assign		i_data = i_ram_data | i_rom_data | i_sdram_data;

keynsham_ram	#(.bus_address(`RAM_ADDRESS),
		  .bus_size(`RAM_SIZE))
		ram(.clk(clk),
		    .i_access(i_access),
		    .i_cs(ram_i_cs),
		    .i_addr(i_addr),
		    .i_data(i_ram_data),
		    .i_ack(i_ram_ack),
		    .d_access(d_access),
		    .d_cs(ram_cs),
		    .d_addr(d_addr),
		    .d_data(ram_data),
		    .d_bytesel(d_bytesel),
		    .d_wr_val(d_data),
		    .d_wr_en(d_wr_en),
		    .d_ack(ram_ack));

keynsham_bootrom #(.bus_address(`BOOTROM_ADDRESS),
		   .bus_size(`BOOTROM_SIZE))
		 rom(.clk(clk),
		     .i_access(i_access),
		     .i_cs(rom_i_cs),
		     .i_addr(i_addr),
		     .i_data(i_rom_data),
		     .i_ack(i_rom_ack),
		     .d_access(d_access),
		     .d_cs(rom_cs),
		     .d_addr(d_addr),
		     .d_data(rom_data),
		     .d_bytesel(d_bytesel),
		     .d_ack(rom_ack));

keynsham_sdram	#(.bus_address(`SDRAM_ADDRESS),
		  .bus_size(`SDRAM_SIZE),
		  .ctrl_bus_address(`SDRAM_CTRL_ADDRESS),
		  .ctrl_bus_size(`SDRAM_CTRL_SIZE),
		  .clkf(`CPU_CLOCK_SPEED))
		sdram(.clk(clk),
		      .ctrl_cs(d_sdram_ctrl_cs),
		      .d_access(d_access),
		      .d_cs(d_sdram_cs),
		      .d_addr(d_addr),
		      .d_wr_val(d_data),
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

`CONFIG_UART	#(.bus_address(`UART_ADDRESS),
		  .bus_size(`UART_SIZE))
		  uart(.clk(clk),
		       .bus_access(d_access),
		       .bus_cs(uart_cs),
		       .bus_addr(d_addr),
		       .bus_wr_val(d_data),
		       .bus_wr_en(d_wr_en),
		       .bus_bytesel(d_bytesel),
		       .bus_error(uart_error),
		       .bus_ack(uart_ack),
		       .bus_data(uart_data),
		       .rx(uart_rx),
		       .tx(uart_tx));

keynsham_irq	#(.nr_irqs(4),
		  .bus_address(`IRQ_ADDRESS),
		  .bus_size(`IRQ_SIZE))
		irq(.clk(clk),
		    .rst(dbg_rst),
		    .bus_access(d_access),
		    .bus_cs(irq_cs),
		    .bus_addr(d_addr),
		    .bus_wr_val(d_data),
		    .bus_wr_en(d_wr_en),
		    .bus_bytesel(d_bytesel),
		    .bus_error(irq_error),
		    .bus_ack(irq_ack),
		    .bus_data(irq_data),
		    .irq_in(irqs),
		    .irq_req(irq_req));

keynsham_timer_block	#(.bus_address(`TIMER_ADDRESS),
			  .bus_size(`TIMER_SIZE))
			timer(.clk(clk),
			      .rst(dbg_rst),
			      .bus_access(d_access),
			      .bus_cs(timer_cs),
			      .bus_addr(d_addr),
			      .bus_wr_val(d_data),
			      .bus_wr_en(d_wr_en),
			      .bus_bytesel(d_bytesel),
			      .bus_error(timer_error),
			      .bus_ack(timer_ack),
			      .bus_data(timer_data),
			      .irqs(timer_irqs));

keynsham_spimaster	#(.bus_address(`SPIMASTER_ADDRESS),
			  .bus_size(`SPIMASTER_SIZE),
                          .num_cs(spi_num_cs))
			spi(.clk(clk),
			    .bus_access(d_access),
			    .bus_cs(spimaster_cs),
			    .bus_addr(d_addr),
			    .bus_wr_val(d_data),
			    .bus_wr_en(d_wr_en),
			    .bus_bytesel(d_bytesel),
			    .bus_error(spimaster_error),
			    .bus_ack(spimaster_ack),
			    .bus_data(spimaster_data),
			    .miso(miso),
			    .mosi(mosi),
			    .sclk(sclk),
                            .ncs(spi_ncs));

`ifdef GPIO_ADDRESS
keynsham_gpio           #(.bus_address(`GPIO_ADDRESS),
			  .bus_size(`GPIO_SIZE),
			  .num_banks(2))
			gpioinst(.clk(clk),
				 .bus_access(d_access),
				 .bus_cs(gpio_cs),
				 .bus_addr(d_addr),
				 .bus_wr_val(d_data),
				 .bus_wr_en(d_wr_en),
				 .bus_bytesel(d_bytesel),
				 .bus_error(gpio_error),
				 .bus_ack(gpio_ack),
				 .bus_data(gpio_data),
				 .gpio(gpio));

`else
assign          gpio_data = 32'b0;
assign          gpio_ack = 1'b0;
assign          gpio_error = 1'b0;
assign		gpio_cs = 1'b0;
`endif

oldland_cpu	#(.icache_size(`ICACHE_SIZE),
		  .icache_line_size(`ICACHE_LINE_SIZE),
                  .icache_num_ways(`ICACHE_NUM_WAYS),
                  .dcache_size(`DCACHE_SIZE),
                  .dcache_line_size(`DCACHE_LINE_SIZE),
                  .dcache_num_ways(`DCACHE_NUM_WAYS),
		  .cpuid_manufacturer(`CPUID_MANUFACTURER),
		  .cpuid_model(`CPUID_MODEL),
		  .cpu_clock_speed(`CPU_CLOCK_SPEED),
		  .itlb_num_entries(`ITLB_NUM_ENTRIES),
		  .dtlb_num_entries(`DTLB_NUM_ENTRIES))
		cpu(.clk(clk),
		    .running(running),
		    .irq_req(irq_req),
		    .rst_req(rst_req),
		    .i_access(i_access),
		    .i_addr(i_addr),
		    .i_data(i_data),
		    .i_ack(i_ack),
		    .i_error(i_error),
		    .d_addr(d_addr),
		    .d_data(d_data),
		    .d_bytesel(d_bytesel),
		    .d_wr_en(d_wr_en),
		    .d_wr_val(cpu_d_out),
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
