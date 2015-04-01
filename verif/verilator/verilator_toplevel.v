`include "keynsham_defines.v"

module verilator_toplevel(input wire clk /*verilator public*/,
			  input wire dbg_clk /*verilator public*/);

`define NUM_SPI_CS	2

wire		rx;
wire		tx;

wire		s_ras_n;
wire		s_cas_n;
wire		s_wr_en;
wire [1:0]	s_bytesel;
wire [12:0]	s_addr;
wire		s_cs_n;
wire		s_clken;
wire [15:0]	s_data;
wire [1:0]	s_banksel;

wire [1:0]	dbg_addr;
wire [31:0]	dbg_din;
wire [31:0]	dbg_dout;
wire		dbg_wr_en;
wire		dbg_req;
wire		dbg_ack;

/* SPI. */
wire		miso;
wire		mosi;
wire		sclk;
wire [`NUM_SPI_CS - 1:0] spi_ncs;

wire		running;

`ifdef GPIO_ADDRESS
/* verilator lint_off UNUSED */
wire [63:0]	gpio;
/* verilator lint_on UNUSED */
`endif

keynsham_soc	#(.spi_num_cs(`NUM_SPI_CS))
		soc(.clk(clk),
		    .rst_req(1'b0),
		    .uart_rx(rx),
		    .uart_tx(tx),
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
		    .miso(miso),
		    .mosi(mosi),
		    .sclk(sclk),
		    .spi_ncs(spi_ncs),
`ifdef GPIO_ADDRESS
		    .gpio(gpio),
`endif
		    .running(running));

debug_controller	dbg(.clk(dbg_clk),
			    .addr(dbg_addr),
			    .read_data(dbg_dout),
			    .write_data(dbg_din),
			    .wr_en(dbg_wr_en),
			    .req(dbg_req),
			    .ack(dbg_ack));

spislave	#(.csnum(0))
		dummy_slave(.clk(sclk),
			    .miso(mosi),
			    .mosi(miso),
			    .ncs(spi_ncs[0]));

initial begin
	if (!|$test$plusargs("interactive")) begin
		$display();
	end
end

endmodule
