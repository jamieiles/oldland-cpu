module sim_instr_rom(input wire clk,
		     input wire [31:0] addr,
		     output reg [31:0] data);

reg [7:0] instr_rom [127:0];
reg [8 * 128:0] rom_filename;

initial begin
	if (!$value$plusargs("romfile=%s", rom_filename) ||
	    rom_filename == 0) begin
		$display("+romfile=PATH_TO_ROM.hex required");
		$finish;
	end
	$readmemh(rom_filename, instr_rom);
	data = 32'hffffffff;
end

always @(posedge clk) begin
	data <= { instr_rom[addr + 3],
		  instr_rom[addr + 2],
		  instr_rom[addr + 1],
		  instr_rom[addr + 0] };
end

endmodule
