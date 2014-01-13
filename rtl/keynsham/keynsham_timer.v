module keynsham_timer(input wire	clk,
		      input wire	rst,
		      input wire	bus_access,
		      input wire	timer_cs,
		      input wire [1:0]	reg_sel,
		      input wire [31:0]	bus_wr_val,
		      input wire	bus_wr_en,
		      input wire [3:0]	bus_bytesel,
		      output reg	bus_error,
		      output reg	bus_ack,
		      output reg [31:0]	bus_data,
		      output wire	irq_out);

localparam REG_COUNT			= 2'd0;
localparam REG_RELOAD			= 2'd1;
localparam REG_CONTROL			= 2'd2;
localparam REG_EOI			= 2'd3;

reg [31:0]	reload_val = 32'hffffffff;
reg [31:0]	count = 32'hffffffff;

reg		periodic = 1'b0;
reg		enabled = 1'b0;
reg		irq_enable = 1'b0;
reg		irq_active = 1'b0;
reg		irq_cleared = 1'b0;

wire [31:0]	reg_count = count;
wire [31:0]	reg_reload = reload_val;
wire [31:0]	reg_control = {29'b0, irq_enable, enabled, periodic};

wire		timer_access = bus_access && timer_cs;
assign		irq_out = irq_active & irq_enable;

initial begin
	bus_error = 1'b0;
	bus_ack = 1'b0;
	bus_data = 32'b0;
end

always @(*) begin
	case (reg_sel)
	REG_COUNT: bus_data = reg_count;
	REG_RELOAD: bus_data = reg_reload;
	REG_CONTROL: bus_data = reg_control;
	REG_EOI: bus_data = 32'b0;
	endcase
end

always @(posedge clk) begin
	if (enabled) begin
		if (|count && !periodic && enabled)
			count <= count - 32'b1;
		else if (periodic && enabled)
			count <= count - 32'b1;
		if (~|count && irq_enable && !irq_active && !irq_cleared)
			irq_active <= 1'b1;
	end

	if (rst) begin
		reload_val <= 32'hffffffff;
		count <= 32'hffffffff;
		periodic <= 1'b0;
		enabled <= 1'b0;
		irq_enable <= 1'b0;
		irq_active <= 1'b0;
		irq_cleared <= 1'b0;
	end else if (timer_access && bus_wr_en) begin
		case (reg_sel)
		REG_COUNT: /* Read-only. */;
		REG_RELOAD: begin
			reload_val <= bus_wr_val;
			count <= bus_wr_val;
			irq_cleared <= 1'b0;
		end
		REG_CONTROL: {irq_enable, enabled, periodic} <= bus_wr_val[2:0];
		REG_EOI: begin
			irq_active <= 1'b0;
			irq_cleared <= 1'b1;
		end
		endcase
	end
end

always @(posedge clk)
	bus_ack <= timer_access;

endmodule
