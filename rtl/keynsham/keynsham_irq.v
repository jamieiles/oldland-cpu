/*
 * Simple IRQ controller.  Supports a maximum of 32 IRQ sources, has an active
 * high (irq_req) output when any enabled IRQ is active.
 */
module keynsham_irq(input wire			clk,
		    input wire			rst,
		    input wire			bus_access,
		    output wire			bus_cs,
		    input wire [29:0]		bus_addr,
		    input wire [31:0]		bus_wr_val,
		    input wire			bus_wr_en,
		    /* verilator lint_off UNUSED */
		    input wire [3:0]		bus_bytesel,
		    /* verilator lint_on UNUSED */
		    output reg			bus_error,
		    output reg			bus_ack,
		    output wire [31:0]		bus_data,
		    input wire [nr_irqs - 1:0]	irq_in,
		    output wire			irq_req);

parameter bus_address = 32'h0;
parameter bus_size = 32'h0;
parameter nr_irqs	= 4;

wire            access_status = {28'b0, bus_addr[1:0], 2'b0} == `IRQ_CTRL_STATUS_REG_OFFS;
wire            access_enable = {28'b0, bus_addr[1:0], 2'b0} == `IRQ_CTRL_ENABLE_REG_OFFS;
wire            access_disable = {28'b0, bus_addr[1:0], 2'b0} == `IRQ_CTRL_DISABLE_REG_OFFS;
wire            access_test = {28'b0, bus_addr[1:0], 2'b0} == `IRQ_CTRL_TEST_REG_OFFS;

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

cs_gen		#(.address(bus_address), .size(bus_size))
		d_cs_gen(.bus_addr(bus_addr), .cs(bus_cs));

initial begin
	bus_error = 1'b0;
	bus_ack = 1'b0;
end

always @(*) begin
	if (access_status)
                data = reg_irq_status;
        else if (access_enable)
	        data = reg_irq_enable;
        else if (access_disable)
	        data = reg_irq_disable;
        else if (access_test)
	        data = reg_irq_test;
        else
                data = 32'b0;
end

always @(posedge clk) begin
	if (rst) begin
		irq_status <= 32'b0;
		irq_enabled <= 32'b0;
		irq_test <= 32'b0;
	end else if (ctrl_access && bus_wr_en) begin
                if (access_enable)
		        irq_enabled <= irq_enabled | bus_wr_val;
                else if (access_disable)
		        irq_enabled <= irq_enabled & ~bus_wr_val;
                else if (access_test)
		        irq_test <= bus_wr_val;
	end
end

always @(posedge clk)
	bus_ack <= ctrl_access;

endmodule
