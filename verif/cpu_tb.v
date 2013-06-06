module cpu_tb();

reg clk = 1'b0;
wire clk180 = ~clk;

wire rx;
wire tx;
wire rx_rdy;
reg rx_rdy_clr = 1'b0;
wire [7:0] uart_rx_data;

wire s_ras_n;
wire s_cas_n;
wire s_wr_en;
wire [1:0] s_bytesel;
wire [12:0] s_addr;
wire s_cs_n;
wire s_clken;
wire [15:0] s_data;
wire [1:0] s_banksel;

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
		    .s_banksel(s_banksel));

uart		tb_uart(.clk_50m(clk),
			.wr_en(0),
			.din(8'b0),
			.tx(rx),
			.rx(tx),
			.rdy(rx_rdy),
			.rdy_clr(rx_rdy_clr),
			.dout(uart_rx_data));

initial begin
	$dumpfile("cpu.lxt");
	$dumpvars(0, cpu_tb);
	#1500000;
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
