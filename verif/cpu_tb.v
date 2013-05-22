module cpu_tb();

reg clk = 1'b0;

always #1 clk = ~clk;

oldland_cpu cpu(.clk(clk));

initial begin
	$dumpfile("cpu.vcd");
	$dumpvars(0, cpu_tb);
	#256 $finish;
end

endmodule
