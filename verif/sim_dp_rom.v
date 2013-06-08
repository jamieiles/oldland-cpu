module sim_dp_rom(input wire clk,
		  input wire [31:0] i_addr,
		  output reg [31:0] i_data,
		  input wire d_access,
		  input wire d_cs,
		  input wire [31:0] d_addr,
		  input wire [3:0] d_bytesel,
		  output reg [31:0] d_data,
		  output reg d_ack);

reg [7:0] rom [255:0];
reg [8 * 128:0] rom_filename;

initial begin
	if (!$value$plusargs("romfile=%s", rom_filename) ||
	    rom_filename == 0) begin
		$display("+romfile=PATH_TO_rom.hex required");
		$finish;
	end
	$readmemh(rom_filename, rom);
	i_data = 32'hffffffff;
	d_data = 32'h00000000;
	d_ack = 1'b0;
end

always @(posedge clk) begin
	i_data <= { rom[i_addr + 3],
		    rom[i_addr + 2],
		    rom[i_addr + 1],
		    rom[i_addr + 0] };
	if (d_access && d_cs) begin
		if (d_bytesel[3])
			d_data[31:24] <= rom[d_addr + 3];
		if (d_bytesel[2])
			d_data[23:16] <= rom[d_addr + 2];
		if (d_bytesel[1])
			d_data[15:8] <= rom[d_addr + 1];
		if (d_bytesel[0])
			d_data[7:0] <= rom[d_addr + 0];
	end else begin
		d_data <= 32'b0;
	end

	d_ack <= d_access && d_cs;
end

endmodule
