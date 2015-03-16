module keynsham_timer(input wire	clk,
		      input wire	rst,
		      input wire	bus_access,
		      input wire	timer_cs,
		      input wire [1:0]	reg_sel,
		      input wire [31:0]	bus_wr_val,
		      input wire	bus_wr_en,
		      /* verilator lint_off UNUSED */
		      input wire [3:0]	bus_bytesel,
		      /* verilator lint_on UNUSED */
		      output reg	bus_error,
		      output reg	bus_ack,
		      output reg [31:0]	bus_data,
		      output wire	irq_out);

reg [31:0]	reload_val = 32'hffffffff;
reg [31:0]	count = 32'hffffffff;

reg		periodic = 1'b0;
reg		enabled = 1'b0;
reg		irq_enable = 1'b0;
reg		irq_active = 1'b0;

wire [31:0]	reg_count = count;
wire [31:0]	reg_reload = reload_val;
wire [31:0]	reg_control = {29'b0, irq_enable, enabled, periodic};

wire		timer_access = bus_access && timer_cs;
assign		irq_out = irq_active & irq_enable;

wire            access_count = {28'b0, reg_sel[1:0], 2'b0} == `TIMER_COUNT_REG_OFFS;
wire            access_reload = {28'b0, reg_sel[1:0], 2'b0} == `TIMER_RELOAD_REG_OFFS;
wire            access_control = {28'b0, reg_sel[1:0], 2'b0} == `TIMER_CONTROL_REG_OFFS;
wire            access_eoi = {28'b0, reg_sel[1:0], 2'b0} == `TIMER_EOI_REG_OFFS;

wire		timer_complete = enabled && count == 32'b1;

initial begin
	bus_error = 1'b0;
	bus_ack = 1'b0;
	bus_data = 32'b0;
end

always @(*) begin
        if (access_count)
	        bus_data = reg_count;
        else if (access_reload)
	        bus_data = reg_reload;
        else if (access_control)
	        bus_data = reg_control;
        else
                bus_data = 32'b0;
end

always @(posedge clk) begin
	if (enabled) begin
		if (|count && !periodic && enabled)
			count <= count - 32'b1;
		else if (~|count && periodic && enabled)
			count <= reload_val;
		else if (periodic && enabled)
			count <= count - 32'b1;

		if (timer_complete && irq_enable)
			irq_active <= 1'b1;
	end

	if (rst) begin
		reload_val <= 32'hffffffff;
		count <= 32'hffffffff;
		periodic <= 1'b0;
		enabled <= 1'b0;
		irq_enable <= 1'b0;
		irq_active <= 1'b0;
	end else if (timer_access && bus_wr_en) begin
                if (access_reload) begin
			reload_val <= bus_wr_val;
			count <= bus_wr_val;
		end

                if (access_control)
		        {irq_enable, enabled, periodic} <= bus_wr_val[2:0];

		if (access_eoi)
			irq_active <= 1'b0;
	end
end

always @(posedge clk)
	bus_ack <= timer_access;

endmodule
