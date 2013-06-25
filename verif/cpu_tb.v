module cpu_tb();

reg clk = 1'b0;
wire clk180 = ~clk;

wire rx;
wire tx;
wire rx_rdy;
reg rx_rdy_clr = 1'b0;
wire [7:0] uart_rx_data;
reg [7:0] uart_tx_data = 8'b0;
reg uart_tx_en = 1'b0;
wire uart_tx_busy;

wire s_ras_n;
wire s_cas_n;
wire s_wr_en;
wire [1:0] s_bytesel;
wire [12:0] s_addr;
wire s_cs_n;
wire s_clken;
wire [15:0] s_data;
wire [1:0] s_banksel;

wire [1:0] dbg_addr;
wire [31:0] dbg_din;
wire [31:0] dbg_dout;
wire dbg_wr_en;
wire dbg_req;
wire dbg_acl;

always #10 clk = ~clk;

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

keynsham_soc	soc(.clk(clk),
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
		    .dbg_clk(clk),
		    .dbg_addr(dbg_addr),
		    .dbg_din(dbg_din),
		    .dbg_dout(dbg_dout),
		    .dbg_wr_en(dbg_wr_en),
		    .dbg_req(dbg_req),
		    .dbg_ack(dbg_ack));

uart		tb_uart(.clk_50m(clk),
			.wr_en(uart_tx_en),
			.din(uart_tx_data),
			.tx_busy(uart_tx_busy),
			.tx(rx),
			.rx(tx),
			.rdy(rx_rdy),
			.rdy_clr(rx_rdy_clr),
			.dout(uart_rx_data));

debug_controller	dbg(.clk(clk),
			    .addr(dbg_addr),
			    .read_data(dbg_dout),
			    .write_data(dbg_din),
			    .wr_en(dbg_wr_en),
			    .req(dbg_req),
			    .ack(dbg_ack));

initial begin
	$dumpfile("cpu.lxt");
	$dumpvars(0, cpu_tb);
	if (!$test$plusargs("interactive")) begin
		#15000000;
		$display();
		$finish;
	end
end

reg [8:0] uart_buf = 9'b0;

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

endmodule
