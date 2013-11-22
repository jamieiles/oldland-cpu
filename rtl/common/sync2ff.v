module sync2ff(input wire	dst_clk,
	       input wire	din,
	       output wire	dout);

reg [1:0]	d = 2'b00;

assign dout = d[1];

always @(posedge dst_clk)
	d[0] <= din;

always @(posedge dst_clk)
	d[1] <= d[0];

endmodule
