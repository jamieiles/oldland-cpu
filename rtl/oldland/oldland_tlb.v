module oldland_tlb(input wire clk,
		   input wire rst,
		   input wire enabled,
		   input wire starting_miss,
		   input wire user_mode,
		   /* Maintenance signals. */
		   input wire inval,
		   input wire [31:0] load_data,
		   input wire load_virt,
		   input wire load_phys,
		   /* Lookup signals. */
		   input wire translate,
		   input wire [31:12] virt,
		   output reg [31:12] phys,
		   output reg [1:0] access,
		   output reg valid,
		   output wire miss,
		   output reg complete);

parameter		nr_entries = 8;
localparam		entry_bits = $clog2(nr_entries);

// verilator lint_off UNUSED
reg [31:0]		next_virt = 32'b0;
// verilator lint_on UNUSED
reg [entry_bits - 1:0]	victim_sel = {entry_bits{1'b0}};
reg [nr_entries - 1:0]	load_entry = {nr_entries{1'b0}};
wire [nr_entries - 1:0] entry_valid;
wire [31:12]		entry_virt[nr_entries - 1:0];
wire [31:12]		entry_phys[nr_entries - 1:0];
wire [1:0]		entry_access[nr_entries - 1:0];
reg [entry_bits:0]	entry_idx = {entry_bits + 1{1'b0}};
reg [entry_bits - 1:0]	entry = {entry_bits{1'b0}};
reg			tlb_miss = 1'b0;
assign			miss = tlb_miss && enabled;

genvar		i;

initial begin
	phys = 20'b0;
	valid = 1'b0;
	complete = 1'b0;
	tlb_miss = 1'b0;
end

generate
	for (i = 0; i < nr_entries; i = i + 1) begin: entries
		oldland_tlb_entry entry(.clk(clk),
					.rst(rst),
					.user_mode(user_mode),
					.inval(inval),
					.virt_in(next_virt[31:12]),
					.phys_in(load_data[31:12]),
					.access_in(next_virt[3:0]),
					.load(load_entry[i]),
					.virt_out(entry_virt[i]),
					.phys_out(entry_phys[i]),
					.access_out(entry_access[i]),
					.valid_out(entry_valid[i]));
	end
endgenerate

always @(posedge clk) begin
	if (load_virt)
		next_virt <= load_data;

	if (rst)
		victim_sel <= {entry_bits{1'b0}};
	if (load_phys)
		victim_sel <= victim_sel + 1'b1;
end

always @(*) begin
	/*
	 * Generate the load signal for an entry.  If there is already
	 * a mapping for a virtual address we need to overwrite that one so we
	 * don't have duplicate entries, otherwise take the next victim in
	 * a round-robin fashion.
	 */
	for (entry_idx = 0; entry_idx < nr_entries; entry_idx = entry_idx + 1'b1) begin
		entry = entry_idx[entry_bits - 1:0];
		if (entry_valid[entry] && entry_virt[entry] == next_virt[31:12] && load_phys)
			load_entry[entry] = 1'b1;
		else
			load_entry[entry] = 1'b0;
	end

	if (~|load_entry && load_phys)
		load_entry[victim_sel] = 1'b1;
end

always @(posedge clk) begin
	if (translate) begin
		valid <= 1'b0;
		tlb_miss <= 1'b0;
		phys <= virt;
		access <= 2'b11;
	end

	complete <= translate;

	if (enabled)
		tlb_miss <= translate;

	for (entry_idx = 0; entry_idx < nr_entries; entry_idx = entry_idx + 1'b1) begin
		if (entry_valid[entry_idx[entry_bits - 1:0]] &&
		    entry_virt[entry_idx[entry_bits - 1:0]] == virt[31:12] &&
		    translate && enabled) begin
			phys <= entry_phys[entry_idx[entry_bits - 1:0]];
			access <= entry_access[entry_idx[entry_bits - 1:0]];
			valid <= 1'b1;
			tlb_miss <= 1'b0;
		end
	end

	/*
	 * If we are starting a new miss then the TLB will be disabled on the
	 * next cycle so we need to make sure that we have a valid output.
	 */
	if ((!enabled || starting_miss)) begin
		phys <= virt;
		valid <= 1'b1;
		tlb_miss <= 1'b0;
		access <= 2'b11;
	end
end

endmodule
