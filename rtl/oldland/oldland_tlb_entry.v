module oldland_tlb_entry(input wire clk,
			 input wire rst,
			 input wire inval,
			 input wire user_mode,
			 input wire [31:12] virt_in,
			 input wire [31:12] phys_in,
			 input wire [3:0] access_in,
			 input wire load,
			 output wire [31:12] virt_out,
			 output wire [31:12] phys_out,
			 output wire [1:0] access_out,
			 output wire valid_out);

reg [31:12]	phys = 20'b0;
reg [31:12]	virt = 20'b0;
reg		valid = 1'b0;
reg [3:0]	access = 4'b00;

assign		virt_out = virt;
assign		phys_out = phys;
assign		valid_out = valid;
assign		access_out = user_mode ? access[3:2] : access[1:0];

always @(posedge clk) begin
	if (rst || inval) begin
		phys <= 20'b0;
		virt <= 20'b0;
		valid <= 1'b0;
		access <= 4'b0000;
	end else if (load) begin
		phys <= phys_in;
		virt <= virt_in;
		access <= access_in;
		valid <= 1'b1;
	end
end

endmodule
