/*
 * Simple IRQ controller.  Supports a maximum of 32 IRQ sources, has an active
 * high (irq_req) output when any enabled IRQ is active.
 */
module keynsham_irq(input wire			clk,
		    input wire			rst,
		    input wire			bus_access,
		    input wire			bus_cs,
		    input wire [29:0]		bus_addr,
		    input wire [31:0]		bus_wr_val,
		    input wire			bus_wr_en,
		    input wire [3:0]		bus_bytesel,
		    output reg			bus_error,
		    output reg			bus_ack,
		    output wire [31:0]		bus_data,
		    input wire [nr_irqs - 1:0]	irq_in,
		    output wire			irq_req);

parameter nr_irqs	= 4;

localparam REG_STATUS	= 2'd0;
localparam REG_ENABLE	= 2'd1;
localparam REG_DISABLE	= 2'd2;
localparam REG_TEST	= 2'd3;

reg [31:0]	irq_status = 32'b0;
reg [31:0]	irq_enabled = 32'b0;
reg [31:0]	irq_test = 32'b0;
wire [31:0]	irq_in_raw = {{(32 - nr_irqs){1'b0}}, irq_in};

wire [31:0]	reg_irq_status = (irq_status | irq_test | irq_in_raw) & irq_enabled;
wire [31:0]	reg_irq_enable = irq_enabled;
wire [31:0]	reg_irq_disable = 32'b0;
wire [31:0]	reg_irq_test = irq_test;

wire		ctrl_access = bus_access && bus_cs;
reg [31:0]	data;
assign bus_data	= bus_ack ? data : 32'b0;

assign irq_req = |reg_irq_status;

initial begin
	bus_error = 1'b0;
	bus_ack = 1'b0;
end

always @(*) begin
	case (bus_addr[1:0])
	REG_STATUS: data = reg_irq_status;
	REG_ENABLE: data = reg_irq_enable;
	REG_DISABLE: data = reg_irq_disable;
	REG_TEST: data = reg_irq_test;
	endcase
end

always @(posedge clk) begin
	if (rst) begin
		irq_status <= 32'b0;
		irq_enabled <= 32'b0;
		irq_test <= 32'b0;
	end else if (ctrl_access && bus_wr_en) begin
		case (bus_addr[1:0])
		REG_STATUS: /* Read-only. */;
		REG_ENABLE: irq_enabled <= irq_enabled | bus_wr_val;
		REG_DISABLE: irq_enabled <= irq_enabled & ~bus_wr_val;
		REG_TEST: irq_test <= bus_wr_val;
		endcase
	end
end

always @(posedge clk)
	bus_ack <= ctrl_access;

endmodule
