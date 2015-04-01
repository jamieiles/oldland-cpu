module toplevel(input wire clk,
		input wire rst_in_n,
		/* UART */
		input wire uart_rx,
		output wire uart_tx,
		/* SDRAM */
		output wire s_ras_n,
		output wire s_cas_n,
		output wire s_wr_en,
		output wire [1:0] s_bytesel,
		output wire [12:0] s_addr,
		output wire s_cs_n,
		output wire s_clken,
		inout [15:0] s_data,
		output wire [1:0] s_banksel,
		output wire sdr_clk,
		/* GPIO */
		output reg running,
		output wire spi_cs0_active,
		output wire spi_cs1_active,
		/* SPI */
		output wire [1:0] spi_ncs,
		/* SPI port 1. */
		output wire spi_clk1,
		output wire spi_mosi1,
		input wire spi_miso1,
		/* SPI port 2. */
		output wire spi_clk2,
		output wire spi_mosi2,
		input wire spi_miso2,
		/* Ethernet control */
		output reg ethernet_reset_n,
		inout wire [63:0] gpio);

wire		sys_clk;
wire		dbg_clk;
wire [1:0]	dbg_addr;
wire [31:0]	dbg_din;
wire [31:0]	dbg_dout;
wire		dbg_wr_en;
wire		dbg_req;
wire		dbg_ack;

wire		cpu_running;
reg		have_run = 1'b0;
reg [19:0]	run_counter = 20'hfffff;

wire		spi_clk;
wire		spi_mosi;
wire		spi_miso = !spi_ncs[0] ? spi_miso1 :
			   !spi_ncs[1] ? spi_miso2 : 1'b1;

reg		rst_req = 1'b0;

assign		spi_mosi1 = spi_mosi;
assign		spi_clk1 = spi_clk;
assign		spi_mosi2 = spi_mosi;
assign		spi_clk2 = spi_clk;

assign		spi_cs0_active = ~spi_ncs[0];
assign		spi_cs1_active = ~spi_ncs[1];

initial		begin
	running = 1'b1;
	ethernet_reset_n = 1'b1;
end

sys_pll		pll(.refclk(clk),
		    .rst(1'b0),
		    .outclk_0(sdr_clk),
		    .outclk_1(sys_clk));

vjtag_debug	debug(.dbg_clk(dbg_clk),
		      .dbg_addr(dbg_addr),
		      .dbg_din(dbg_din),
		      .dbg_dout(dbg_dout),
		      .dbg_wr_en(dbg_wr_en),
		      .dbg_req(dbg_req),
		      .dbg_ack(dbg_ack));

keynsham_soc	#(.spi_num_cs(2))
		soc(.clk(sys_clk),
		    .running(cpu_running),
		    .rst_req(rst_req),
		    .uart_rx(uart_rx),
		    .uart_tx(uart_tx),
		    .s_ras_n(s_ras_n),
		    .s_cas_n(s_cas_n),
		    .s_wr_en(s_wr_en),
		    .s_bytesel(s_bytesel),
		    .s_addr(s_addr),
		    .s_cs_n(s_cs_n),
		    .s_clken(s_clken),
		    .s_data(s_data),
		    .s_banksel(s_banksel),
		    .dbg_clk(dbg_clk),
		    .dbg_addr(dbg_addr),
		    .dbg_din(dbg_din),
		    .dbg_dout(dbg_dout),
		    .dbg_wr_en(dbg_wr_en),
		    .dbg_req(dbg_req),
		    .dbg_ack(dbg_ack),
		    .miso(spi_miso),
		    .mosi(spi_mosi),
		    .sclk(spi_clk),
                    .spi_ncs(spi_ncs),
		    .gpio(gpio));

/*
 * Make the effects of running a little more visible - if we run for at least
 * on cycle in 2^20 cycles then trigger the LED for 2^20 cycles.  This means
 * that there is some visible feedback for a single step and short run periods.
 */
always @(posedge sys_clk) begin
	if (cpu_running)
		have_run <= 1'b1;

	run_counter <= run_counter - 20'b1;
	if (run_counter == 20'h0) begin
		running <= have_run;
		have_run <= 1'b0;
	end
end

always @(posedge sys_clk) begin
	rst_req <= 1'b0;

	if (!rst_in_n)
		rst_req <= 1'b1;
end

endmodule
