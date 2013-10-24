module keynsham_timer_block(input wire		clk,
			    input wire		rst,
			    input wire		bus_access,
			    input wire		bus_cs,
			    input wire [29:0]	bus_addr,
			    input wire [31:0]	bus_wr_val,
			    input wire		bus_wr_en,
			    input wire [3:0]	bus_bytesel,
			    output wire		bus_error,
			    output wire		bus_ack,
			    output wire [31:0]	bus_data);

parameter	nr_timers = 4;

localparam	tbits = $clog2(nr_timers) - 1;

wire [tbits:0]	timer_sel = bus_addr[tbits + 2:2];
wire [tbits:0]	reg_sel = bus_addr[tbits:0];

wire [31:0]	timer_data[0:nr_timers - 1];
wire		timer_ack[0:nr_timers - 1];
wire		timer_error[0:nr_timers - 1];

assign		bus_data = timer_data[timer_sel];
assign		bus_ack = timer_ack[timer_sel];
assign		bus_error = timer_error[timer_sel];


genvar		i;

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
				      .bus_data(timer_data[i]));
	end
endgenerate

endmodule
