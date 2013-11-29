module oldland_cpuid(input wire [2:0]	reg_sel,
		     output reg [31:0]	val);

parameter CPUID_MANUFACTURER = 0;
parameter CPUID_MODEL = 0;

parameter CPU_CLOCK_SPEED = 0;

parameter ICACHE_SIZE = 0;
parameter ICACHE_LINE_SIZE = 0;

parameter DCACHE_SIZE = 0;
parameter DCACHE_LINE_SIZE = 0;

localparam ICACHE_LINES = ICACHE_SIZE / ICACHE_LINE_SIZE;
localparam ICACHE_LINE_WORDS = ICACHE_LINE_SIZE / 4;

wire [31:0] cpuid0 = {CPUID_MANUFACTURER[15:0], CPUID_MODEL[15:0]};
wire [31:0] cpuid1 = CPU_CLOCK_SPEED[31:0];
wire [31:0] cpuid2 = 32'b0;
wire [31:0] cpuid3 = {8'b0, ICACHE_LINES[15:0], ICACHE_LINE_WORDS[7:0]};
wire [31:0] cpuid4 = 32'b0;

always @(*) begin
	case (reg_sel)
	3'h0: val = cpuid0;
	3'h1: val = cpuid1;
	3'h2: val = cpuid2;
	3'h3: val = cpuid3;
	3'h4: val = cpuid4;
	default: val = 32'b0;
	endcase
end

endmodule
