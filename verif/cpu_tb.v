module cpu_tb();

reg clk = 1'b0;

always #1 clk = ~clk;

wire [31:0] i_addr;
wire [31:0] i_data;
wire [31:0] d_addr;
wire [31:0] d_data;
wire [31:0] d_wr_val;
wire [3:0] d_bytesel;
wire d_wr_en;
wire d_access;

sim_dp_ram	ram(.clk(clk),
		    .i_addr(i_addr),
		    .i_data(i_data),
		    .d_cs(d_access),
		    .d_addr(d_addr),
		    .d_data(d_data),
		    .d_bytesel(d_bytesel),
		    .d_wr_en(d_wr_en));

oldland_cpu	cpu(.clk(clk),
		    .i_addr(i_addr),
		    .i_data(i_data),
		    .d_addr(d_addr),
		    .d_data(d_data),
		    .d_bytesel(d_bytesel),
		    .d_wr_en(d_wr_en),
		    .d_wr_val(d_wr_val),
		    .d_access(d_access));

initial begin
	$dumpfile("cpu.vcd");
	$dumpvars(0, cpu_tb);
	#1024 $finish;
end

always @(posedge clk) begin
	if (d_wr_en && d_addr == 32'h80000000)
		$display("uart: writing %c", d_wr_val[7:0]);
end

endmodule
