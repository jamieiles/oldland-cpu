`ifdef GPIO_ADDRESS
module keynsham_gpio(input wire		clk,
		     /* Data bus. */
		     input wire		bus_access,
		     output wire	bus_cs,
		     input wire [29:0]	bus_addr,
		     input wire [31:0]	bus_wr_val,
		     input wire		bus_wr_en,
		     input wire [3:0]	bus_bytesel,
		     output reg		bus_error,
		     output reg		bus_ack,
		     output wire [31:0]	bus_data,
		     /* GPIO */
		     inout wire [ngpio - 1:0] gpio);

parameter       num_banks = 2;
parameter	bus_address = 32'h0;
parameter	bus_size = 32'h0;
localparam	ngpio = num_banks * 32;

wire		banksel = bus_addr[2];
wire [1:0]	regsel = bus_addr[1:0];
wire		access_value = {28'b0, regsel, 2'b00} == `GPIO_VALUE_REG_OFFS;
wire		access_oe = {28'b0, regsel, 2'b00} == `GPIO_OUTPUT_ENABLE_REG_OFFS;
wire		access_set = {28'b0, regsel, 2'b00} == `GPIO_SET_REG_OFFS;
wire		access_clr = {28'b0, regsel, 2'b00} == `GPIO_CLEAR_REG_OFFS;

reg [31:0]	data = 32'b0;
assign		bus_data = bus_ack ? data : 32'b0;

cs_gen		#(.address(bus_address), .size(bus_size))
		d_cs_gen(.bus_addr(bus_addr), .cs(bus_cs));

reg [ngpio - 1:0] gpio_internal = {ngpio{1'bz}};
assign		gpio = gpio_internal;

reg [31:0]	outputs[num_banks - 1:0];
reg [31:0]	oe[num_banks - 1:0];
reg [$clog2(ngpio):0] pin = {$clog2(ngpio) + 1{1'b0}};
reg [31:0]	input_banks[num_banks - 1:0];

initial begin
	bus_error = 1'b0;
	bus_ack = 1'b0;

	/* verilator lint_off WIDTH */
	for (pin = 0; pin < ngpio; pin = pin + 1'b1) begin
		gpio_internal[pin] = 1'bz;
		outputs[pin / 32][pin % 32] = 1'b0;
		oe[pin / 32][pin % 32] = 1'b0;
		input_banks[pin / 32][pin % 32] = 1'b0;
	end
	/* verilator lint_on WIDTH */
end

always @(*) begin
	/* verilator lint_off WIDTH */
	for (pin = 0; pin < ngpio; pin = pin + 1'b1) begin
		gpio_internal[pin] = oe[pin / 32][pin % 32] ? outputs[pin / 32][pin % 32] : 1'bz;
		input_banks[pin / 32][pin % 32] = gpio[pin];
	end
	/* verilator lint_on WIDTH */
end

always @(*) begin
	if (access_value)
		data = (outputs[banksel] & oe[banksel]) | (input_banks[banksel] & ~oe[banksel]);
	else if (access_oe)
		data = oe[banksel];
	else
		data = 32'b0;
end

always @(posedge clk) begin
	if (bus_access && bus_cs && bus_wr_en && bus_bytesel == 4'hf) begin
		if (access_oe)
			oe[banksel] <= bus_wr_val;
		else if (access_set)
			outputs[banksel] <= outputs[banksel] | bus_wr_val;
		else if (access_clr)
			outputs[banksel] <= outputs[banksel] & ~bus_wr_val;
	end
end

always @(posedge clk)
	bus_ack <= bus_access & bus_cs;

always @(posedge clk)
	bus_error <= bus_access & bus_cs & (bus_bytesel != 4'hf);

endmodule
`endif /* GPIO_ADDRESS */
