module sim_dp_ram(input wire		clk,
		  /* Instruction bus. */
		  input wire		i_access,
		  input wire		i_cs,
		  input wire [10:0]	i_addr,
		  output reg [31:0]	i_data,
		  output reg		i_ack,
		  /* Data bus. */
		  input wire		d_access,
		  input wire		d_cs,
		  input wire [10:0]	d_addr,
		  input wire [3:0]	d_bytesel,
		  input wire [31:0]	d_wr_val,
		  input wire		d_wr_en,
		  output reg [31:0]	d_data,
		  output reg		d_ack);

reg [7:0]	ram [4096:0];
reg [8 * 128:0] ram_filename;
reg [$clog2(4096):0]	ram_i;

initial begin
	// verilator lint_off WIDTH
	if ($value$plusargs("ramfile=%s", ram_filename) &&
	    ram_filename != 0)
	// verilator lint_on WIDTH
		$readmemh(ram_filename, ram);
	else
		for (ram_i = 0; ram_i < 4096; ram_i = ram_i + 1)
			ram[ram_i] = 8'b0;
	i_data = 32'hffffffff;
	d_data = 32'h00000000;
	d_ack = 1'b0;
	i_ack = 1'b0;
end

always @(posedge clk) begin
	i_data <= { ram[{i_addr, 2'b00} + 3],
		    ram[{i_addr, 2'b00} + 2],
		    ram[{i_addr, 2'b00} + 1],
		    ram[{i_addr, 2'b00} + 0] };

	if (d_wr_en && d_access && d_cs) begin
		if (d_bytesel[3])
			ram[{d_addr, 2'b00} + 3] <= d_wr_val[31:24];
		if (d_bytesel[2])
			ram[{d_addr, 2'b00} + 2] <= d_wr_val[23:16];
		if (d_bytesel[1])
			ram[{d_addr, 2'b00} + 1] <= d_wr_val[15:8];
		if (d_bytesel[0])
			ram[{d_addr, 2'b00} + 0] <= d_wr_val[7:0];
	end else if (d_access && d_cs) begin
		if (d_bytesel[3])
			d_data[31:24] <= ram[{d_addr, 2'b00} + 3];
		if (d_bytesel[2])
			d_data[23:16] <= ram[{d_addr, 2'b00} + 2];
		if (d_bytesel[1])
			d_data[15:8] <= ram[{d_addr, 2'b00} + 1];
		if (d_bytesel[0])
			d_data[7:0] <= ram[{d_addr, 2'b00} + 0];
	end else begin
		d_data <= 32'b0;
	end

	d_ack <= d_access && d_cs;
end

always @(posedge clk)
	i_ack <= i_access && i_cs;

endmodule
