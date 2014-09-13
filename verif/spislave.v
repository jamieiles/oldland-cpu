module spislave(input wire clk,
		input wire ncs,
		input wire miso,
		output wire mosi);

parameter csnum = 0;

reg [2:0] bit_idx = 3'b0;
reg [7:0] tx_byte = 8'b0;
reg [7:0] rx_byte = 8'b0;

assign mosi = tx_byte[~bit_idx];

always @(posedge clk) begin
	if (!ncs) begin
		rx_byte[~bit_idx] <= miso;

		if (bit_idx == 3'h7)
			$spi_rx_byte_from_master(csnum, {rx_byte[7:1], miso});
		if (bit_idx == 3'b0)
			$spi_get_next_byte_to_master(csnum, tx_byte);

		bit_idx <= bit_idx + 1'b1;
	end
end

endmodule

