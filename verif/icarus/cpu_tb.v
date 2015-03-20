module cpu_tb();

`define NUM_SPI_CS	2

reg		clk = 1'b0;
reg		clk180 = 1'b0;

initial begin
  #8 clk180 = ~clk180;
  forever #10 clk180 = ~clk180;
end
reg		dbg_clk = 1'b1;

wire		rx;
wire		tx;
wire		rx_rdy;
reg		rx_rdy_clr = 1'b0;

`ifndef USE_DEBUG_UART
wire [7:0]	uart_rx_data;
reg [7:0]	uart_tx_data = 8'b0;
reg		uart_tx_en = 1'b0;
wire		uart_tx_busy;

reg [8:0]	uart_buf = 9'b0;
`endif

wire		s_clk = ~clk;
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

mt48lc16m16a2 ram_model(.Dq(s_data),
			.Addr(s_addr),
			.Ba(s_banksel),
			.Clk(clk180),
			.Cke(s_clken),
			.Cs_n(s_cs_n),
			.Ras_n(s_ras_n),
			.Cas_n(s_cas_n),
			.We_n(s_wr_en),
			.Dqm(s_bytesel));

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
		    .spi_ncs(spi_ncs));

`ifndef USE_DEBUG_UART
uart		tb_uart(.clk_50m(clk),
			.wr_en(uart_tx_en),
			.din(uart_tx_data),
			.tx_busy(uart_tx_busy),
			.tx(rx),
			.rx(tx),
			.rdy(rx_rdy),
			.rdy_clr(rx_rdy_clr),
			.dout(uart_rx_data));
`endif

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
	if ($test$plusargs("debug")) begin
		$dumpfile("cpu.lxt");
		$dumpvars(0, cpu_tb);
	end
	if (!$test$plusargs("interactive")) begin
		$display();
	end
end

always #10 clk = ~clk;
always #25 dbg_clk = ~dbg_clk;

`ifndef USE_DEBUG_UART
always @(posedge clk) begin
	if (rx_rdy && !rx_rdy_clr) begin
		if (!$test$plusargs("interactive")) begin
			$write("%c", uart_rx_data);
			$fflush();
		end else
			$uart_put(uart_rx_data);
		rx_rdy_clr <= 1'b1;
	end else begin
		rx_rdy_clr <= 1'b0;
	end

	if (!uart_tx_busy) begin
		$uart_get(uart_buf);
		if (uart_buf[8]) begin
			uart_tx_data <= uart_buf[7:0];
			uart_tx_en <= 1'b1;
		end
	end else begin
		uart_tx_en <= 1'b0;
	end
end
`endif

endmodule
