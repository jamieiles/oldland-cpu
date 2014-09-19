module spislave(input wire clk,
		input wire ncs,
		input wire miso,
		output wire mosi);

`ifdef verilator
`systemc_imp_header
void spi_rx_byte_from_master(IData cs, CData val);
void spi_get_next_byte_to_master(IData cs, CData *val);
`verilog
`endif

parameter csnum /*verilator public*/ = 0;

reg [2:0] bit_idx = 3'b0;
reg [7:0] tx_byte /*verilator public*/ = 8'b0;
reg [7:0] rx_byte /*verilator public*/ = 8'b0;

assign mosi = tx_byte[~bit_idx];

`ifdef verilator
wire [7:0] rx_val /*verilator public*/ = {rx_byte[7:1], miso};
task receive_from_master;
begin
	$c("{spi_rx_byte_from_master(csnum, rx_val);}");
end
endtask
`else
task receive_from_master;
begin
	$spi_rx_byte_from_master(csnum, {rx_byte[7:1], miso});
end
endtask
`endif

`ifdef verilator
reg [7:0] ctx_byte /*verilator public*/ = 8'b0;
task next_byte_to_master;
begin
	$c("{spi_get_next_byte_to_master(csnum, &ctx_byte);}");
	tx_byte <= ctx_byte;
end
endtask
`else
task next_byte_to_master;
begin
	$spi_get_next_byte_to_master(csnum, tx_byte);
end
endtask
`endif

always @(posedge clk) begin
	if (!ncs) begin
		rx_byte[~bit_idx] <= miso;

		if (bit_idx == 3'h7) begin
			receive_from_master();
			next_byte_to_master();
		end

		bit_idx <= bit_idx + 1'b1;
	end
end

endmodule

