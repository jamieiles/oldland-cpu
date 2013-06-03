module cpu_tb();

reg clk = 1'b0;
wire rx;
wire tx;
wire rx_rdy;
reg rx_rdy_clr = 1'b0;
wire [7:0] uart_rx_data;

always #1 clk = ~clk;

keynsham_soc	soc(.clk(clk),
		    .uart_rx(rx),
		    .uart_tx(tx));

uart		tb_uart(.clk_50m(clk),
			.wr_en(0),
			.din(8'b0),
			.tx(rx),
			.rx(tx),
			.rdy(rx_rdy),
			.rdy_clr(rx_rdy_clr),
			.dout(uart_rx_data));

initial begin
	$dumpfile("cpu.vcd");
	$dumpvars(0, cpu_tb);
	#150000;
	$display();
	$finish;
end

always @(posedge clk) begin
	if (rx_rdy && !rx_rdy_clr) begin
		$write("%c", uart_rx_data);
		$fflush();
		rx_rdy_clr <= 1'b1;
	end else begin
		rx_rdy_clr <= 1'b0;
	end
end

endmodule
