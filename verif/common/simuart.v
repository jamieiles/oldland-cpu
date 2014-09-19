module simuart(input wire		clk,
	       input wire		bus_access,
	       output wire		bus_cs,
	       input wire [29:0]	bus_addr,
	       input wire [31:0]	bus_wr_val /*verilator public*/,
	       input wire		bus_wr_en,
	       input wire [3:0]		bus_bytesel,
	       output reg		bus_error,
	       output reg		bus_ack,
	       output reg [31:0]	bus_data,
	       input wire		rx,
	       output wire		tx);

`ifdef verilator
`systemc_imp_header
void uart_get(SData *val);
void uart_put(SData val);
`verilog
`endif

`ifdef verilator
task write_data;
begin
	$c("{uart_put(bus_wr_val);}");
end
endtask
`else
task write_data;
begin
	if (~|$test$plusargs("interactive")) begin
		$write("%c", bus_wr_val[7:0]);
		$fflush();
	end else begin
		$uart_put(bus_wr_val[7:0]);
	end
end
endtask
`endif

`ifdef verilator
reg [8:0] cuart_buf /*verilator public*/ = 9'b0;
task read_data;
begin
	$c("{uart_get(&cuart_buf);}");
        uart_buf <= cuart_buf;
end
endtask
`else
task read_data;
begin
	$uart_get(uart_buf);
end
endtask
`endif

parameter	bus_address = 32'h0;
parameter	bus_size = 32'h0;

reg [8:0]	uart_buf/*verilator public*/ = 9'b0;
wire uart_rdy	= uart_buf[8];

wire [31:0] status_reg = (uart_rdy ? 32'b10 : 32'b0) | 32'b1;

cs_gen		#(.address(bus_address), .size(bus_size))
		d_cs_gen(.bus_addr(bus_addr), .cs(bus_cs));

initial begin
	bus_error = 1'b0;
	bus_ack = 1'b0;
	bus_data = 32'b0;
end

always @(posedge clk) begin
	bus_data <= 32'b0;

	if (~uart_rdy)
		read_data();

	if (bus_access && bus_cs && bus_wr_en) begin
		if (bus_addr[1:0] == 2'b00) begin
			write_data();
		end
	end else if (bus_access && bus_cs) begin
		if (bus_addr[1:0] == 2'b00) begin
			bus_data <= {24'b0, uart_buf[7:0]};
			uart_buf[8] <= 1'b0;
		end else if (bus_addr[1:0] == 2'b01) begin
			/* Status register read. */
			bus_data <= status_reg;
		end
	end

	bus_ack <= bus_access && bus_cs;
end

endmodule
