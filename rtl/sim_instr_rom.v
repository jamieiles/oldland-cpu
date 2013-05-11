module sim_instr_rom(input wire clk,
		     input wire [31:0] addr,
		     output reg [31:0] data);

reg [7:0] instr_rom [127:0];

initial begin
	$readmemh("rom.hex", instr_rom);
	data = 32'hffffffff;
end

always @(posedge clk) begin
	data <= { instr_rom[addr + 3],
		  instr_rom[addr + 2],
		  instr_rom[addr + 1],
		  instr_rom[addr + 0] };
end

endmodule
