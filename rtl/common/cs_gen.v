module cs_gen(input wire [29:0]	bus_addr,
	      output wire	cs);

parameter	address = 32'h00000000;
parameter	size = 32'h00001000;

localparam	cs_mask_bits = 32 - $clog2(size);
localparam	cs_mask = {{cs_mask_bits{1'b1}}, {32 - cs_mask_bits - 2{1'b0}}};

assign		cs = (bus_addr & cs_mask) == address[31:2];

endmodule
