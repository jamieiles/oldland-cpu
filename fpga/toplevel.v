module toplevel(input wire clk,
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
		output wire [1:0] s_banksel,
		output wire sdr_clk);

wire sys_clk;

sys_pll		pll(.inclk0(clk),
		    .c0(sys_clk),
		    .c1(sdr_clk));

keynsham_soc	soc(.clk(sys_clk),
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
		    .dbg_clk(1'b0),
		    .dbg_addr(2'b0),
		    .dbg_din(32'b0),
		    .dbg_wr_en(1'b0),
		    .dbg_req(1'b0));

endmodule
