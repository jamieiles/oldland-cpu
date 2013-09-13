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

wire		sys_clk;
wire		dbg_clk;
wire [1:0]	dbg_addr;
wire [31:0]	dbg_din;
wire [31:0]	dbg_dout;
wire		dbg_wr_en;
wire		dbg_req;
wire		dbg_ack;

sys_pll		pll(.inclk0(clk),
		    .c0(sys_clk),
		    .c1(sdr_clk));

vjtag_debug	debug(.dbg_clk(dbg_clk),
		      .dbg_addr(dbg_addr),
		      .dbg_din(dbg_din),
		      .dbg_dout(dbg_dout),
		      .dbg_wr_en(dbg_wr_en),
		      .dbg_req(dbg_req),
		      .dbg_ack(dbg_ack));

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
		    .dbg_clk(dbg_clk),
		    .dbg_addr(dbg_addr),
		    .dbg_din(dbg_din),
		    .dbg_dout(dbg_dout),
		    .dbg_wr_en(dbg_wr_en),
		    .dbg_req(dbg_req),
		    .dbg_ack(dbg_ack));

endmodule
