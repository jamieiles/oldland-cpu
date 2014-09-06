module keynsham_timer_block(input wire			clk,
			    input wire			rst,
			    input wire			bus_access,
			    output wire			bus_cs,
			    input wire [29:0]		bus_addr,
			    input wire [31:0]		bus_wr_val,
			    input wire			bus_wr_en,
			    input wire [3:0]		bus_bytesel,
			    output wire			bus_error,
			    output wire			bus_ack,
			    output wire [31:0]		bus_data,
			    output wire [nr_timers - 1:0] irqs);

parameter	bus_address = 32'h0;
parameter	bus_size = 32'h0;
parameter	nr_timers = 4;

localparam	tbits = $clog2(nr_timers) - 1;

wire [tbits:0]	timer_sel = bus_addr[tbits + 2:2];
wire [tbits:0]	reg_sel = bus_addr[tbits:0];

wire [31:0]	timer_data[nr_timers - 1:0];
wire [nr_timers - 1:0] timer_ack;
wire [nr_timers - 1:0] timer_error;

wire [31:0]	data = timer_data[timer_sel];

assign		bus_ack = |timer_ack;
assign		bus_error = |timer_error;

assign		bus_data = timer_ack[timer_sel] ? data : 32'b0;

genvar		i;

cs_gen		#(.address(bus_address), .size(bus_size))
		d_cs_gen(.bus_addr(bus_addr), .cs(bus_cs));

generate
	for (i = 0; i < nr_timers; i = i + 1) begin: timers
		keynsham_timer	timer(.clk(clk),
				      .rst(rst),
				      .bus_access(bus_access),
				      .timer_cs(bus_cs & i[tbits:0] == timer_sel),
				      .reg_sel(reg_sel),
				      .bus_wr_val(bus_wr_val),
				      .bus_wr_en(bus_wr_en),
				      .bus_bytesel(bus_bytesel),
				      .bus_error(timer_error[i]),
				      .bus_ack(timer_ack[i]),
				      .bus_data(timer_data[i]),
				      .irq_out(irqs[i]));
	end
endgenerate

endmodule
