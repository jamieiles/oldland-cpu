module sim_dp_rom(input wire		clk,
		  /* Instruction bus. */
		  input wire		i_access,
		  input wire		i_cs,
		  input wire [11:0]	i_addr,
		  output reg [31:0]	i_data,
		  output reg		i_ack,
		  /* Data bus. */
		  input wire		d_access,
		  input wire		d_cs,
		  input wire [11:0]	d_addr,
		  input wire [3:0]	d_bytesel,
		  output reg [31:0]	d_data,
		  output reg		d_ack);

localparam BOOTROM_BYTES = 16384;

reg [7:0]	rom [BOOTROM_BYTES - 1:0];
reg [8 * 128:0] rom_filename;

initial begin
	// verilator lint_off WIDTH
	if (!$value$plusargs("romfile=%s", rom_filename) ||
	    rom_filename == 0) begin
		$display("+romfile=PATH_TO_rom.hex required");
		$finish;
	end
	// verilator lint_on WIDTH
	$readmemh(rom_filename, rom, 0, BOOTROM_BYTES - 1);
	i_data = 32'hffffffff;
	d_data = 32'h00000000;
	d_ack = 1'b0;
	i_ack = 1'b0;
end

always @(posedge clk) begin
	i_data <= { rom[{i_addr, 2'b00} + 3],
		    rom[{i_addr, 2'b00} + 2],
		    rom[{i_addr, 2'b00} + 1],
		    rom[{i_addr, 2'b00} + 0] };
	if (d_access && d_cs) begin
		if (d_bytesel[3])
			d_data[31:24] <= rom[{d_addr, 2'b00} + 3];
		if (d_bytesel[2])
			d_data[23:16] <= rom[{d_addr, 2'b00} + 2];
		if (d_bytesel[1])
			d_data[15:8] <= rom[{d_addr, 2'b00} + 1];
		if (d_bytesel[0])
			d_data[7:0] <= rom[{d_addr, 2'b00} + 0];
	end else begin
		d_data <= 32'b0;
	end

	d_ack <= d_access && d_cs;
end

always @(posedge clk)
	i_ack <= i_access && i_cs;

endmodule
