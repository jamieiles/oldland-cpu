/*
 * Virtual JTAG interface to the Oldland debug control unit.
 */
module vjtag_debug(output wire		dbg_clk,
		   output wire [1:0]	dbg_addr,
		   output wire [31:0]	dbg_din,
		   input wire [31:0]	dbg_dout,
		   output reg		dbg_wr_en,
		   output reg		dbg_req,
		   input wire		dbg_ack);

wire		tdi;
wire		tdo;
wire		sdr;
wire		e1dr;
wire		cdr;
wire		udr;
wire [3:0]	ir_in;
wire		write = ir_in[3];
reg [31:0]	data = 32'b0;
/*
 * Command status.  Represented as the LSB in DR4.  Reading the status bit
 * clears the request.
 */
reg		status = 1'b0;
reg		bypass = 1'b0;

assign dbg_addr	= ir_in[1:0];
assign dbg_din	= data;

jtag		j(.tck(dbg_clk),
		  .tdo(tdo),
		  .tdi(tdi),
		  .ir_in(ir_in),
		  .virtual_state_sdr(sdr),
		  .virtual_state_e1dr(e1dr),
		  .virtual_state_cdr(cdr),
		  .virtual_state_udr(udr));

initial begin
	dbg_req = 1'b0;
	dbg_wr_en = 1'b0;
end

always @(posedge dbg_clk) begin
	if (!status && dbg_ack)
		status <= 1'b1;

	if (cdr && ir_in[2:0] == 3'b100) begin
		data <= {31'b0, status};
		status <= 1'b0;
	end else if (cdr)
		data <= dbg_dout;
	else if (sdr)
		data <= {tdi, data[31:1]};
end

always @(posedge dbg_clk)
	dbg_wr_en <= e1dr && write;

always @(posedge dbg_clk) begin
	if (udr && write && ~|dbg_addr && !status)
		dbg_req <= 1'b1;
	if (dbg_ack && dbg_req)
		dbg_req <= 1'b0;
end

always @(posedge dbg_clk)
	bypass <= tdi;

assign tdo = sdr ? data[0] : bypass;

endmodule
