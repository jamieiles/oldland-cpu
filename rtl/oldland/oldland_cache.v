`include "oldland_defs.v"

module oldland_cache(input wire		clk,
		     input wire		rst,
		     input wire		enabled,
		     /* CPU<->cache bus signals. */
		     input wire		c_access,
		     input wire	[29:0]	c_addr,
		     input wire [31:0]	c_wr_val,
		     input wire		c_wr_en,
		     output reg [31:0]	c_data,
		     input wire [3:0]	c_bytesel,
		     output wire	c_ack,
		     output wire	c_error,
		     /* CPU<->cache control signals. */
		     input wire		c_inval,
		     input wire		c_flush,
		     /* Debug control signals. */
		     input wire		dbg_inval,
		     input wire		dbg_flush,
		     output wire	dbg_complete,
		     input wire [CACHE_INDEX_BITS - 1:0] c_index,
		     output wire	cacheop_complete,
		     /* Cache<->memory signals. */
		     output wire	m_access,
		     output wire [29:0]	m_addr,
		     output wire [31:0]	m_wr_val,
		     output wire	m_wr_en,
		     output wire [3:0]	m_bytesel,
		     input wire [31:0]	m_data,
		     input wire		m_ack,
		     input wire		m_error,
		     /* TLB signals. */
		     output reg		tlb_translate,
		     output reg [31:12] tlb_virt,
		     input wire [31:12]	tlb_phys,
		     input wire		tlb_valid,
		     input wire		tlb_miss,
		     input wire		tlb_complete,
		     input wire [1:0]	tlb_access);

parameter cache_size		= 8192;
parameter cache_line_size	= 32;
parameter read_only		= 1'b0;
parameter num_ways		= 2;

localparam way_size		= cache_size / num_ways;

localparam LINES_PER_WAY	= way_size / cache_line_size;
localparam CACHE_INDEX_BITS	= $clog2(LINES_PER_WAY);

localparam STATE_IDLE		= 5'b00001;
localparam STATE_CACHED		= 5'b00010;
localparam STATE_BYPASS		= 5'b00100;
localparam STATE_WRITE_MISS	= 5'b01000;
localparam STATE_FLUSH		= 5'b10000;

reg [$clog2(num_ways) - 1:0]	victim_sel = {$clog2(num_ways){1'b0}};

reg [4:0]			state = STATE_CACHED;
reg [4:0]			next_state = STATE_CACHED;

wire [num_ways - 1:0]		wm_access;
wire [29:0]			wm_addr[num_ways - 1:0];
wire [31:0]			wm_wr_val[num_ways - 1:0];
wire [31:0]			wc_data[num_ways - 1:0];
wire [num_ways - 1:0]		wc_ack;
wire [num_ways - 1:0]		wc_error;
wire [num_ways - 1:0]		wm_wr_en;
wire [3:0]			wm_bytesel[num_ways - 1:0];
wire [num_ways - 1:0]		w_hit;
wire [num_ways - 1:0]		w_filled;

reg [num_ways - 1:0]		completed_dbg_ops = {num_ways{1'b0}};
wire [num_ways - 1:0]		w_dbg_complete;
assign				dbg_complete = &(completed_dbg_ops | w_dbg_complete);

reg [num_ways - 1:0]		completed_cacheops = {num_ways{1'b0}};
wire [num_ways - 1:0]		w_cacheop_complete;
assign				cacheop_complete = &(completed_cacheops | w_cacheop_complete);

reg				latched_access = 1'b0;
reg				latched_wr_en = 1'b0;
/* verilator lint_off UNUSED */
reg [29:0]			latched_addr = 30'b0;
/* verilator lint_on UNUSED */
reg [31:0]			latched_wr_val = 32'b0;
reg [3:0]			latched_bytesel = 4'b0;

reg				read_from_bypass = 1'b0;
reg [31:0]			bypass_data = 32'b0;
assign				c_ack = |wc_ack | bypass_ack | c_error;
assign				c_error = |wc_error | bypass_error | (tlb_complete && ~access_ok);

reg				bypass = 1'b0;
reg				bypass_access = 1'b0;
reg				bypass_error = 1'b0;
reg				bypass_ack = 1'b0;
assign				m_access = bypass ? bypass_access : wm_access[victim_sel];
assign				m_addr = bypass ? {tlb_phys, latched_addr[9:0]} : wm_addr[victim_sel];
assign				m_wr_val = bypass ? latched_wr_val : wm_wr_val[victim_sel];
assign				m_wr_en = bypass ? latched_wr_en : wm_wr_en[victim_sel];
assign				m_bytesel = bypass ? latched_bytesel : wm_bytesel[victim_sel];

wire				access_ok = 
					((latched_wr_en && tlb_access[`TLB_WRITE]) ||
					 (!latched_wr_en && tlb_access[`TLB_READ]));

integer way;

initial begin
	c_data = 32'b0;
	tlb_virt = 20'b0;
end

genvar i;

generate
for (i = 0; i < num_ways; i = i + 1) begin: ways

oldland_cache_way	#(.way_size(way_size),
			  .cache_line_size(cache_line_size),
			  .read_only(read_only))
			way(.clk(clk),
			    .rst(rst),
			    .enabled(enabled),
			    .hit(w_hit[i]),
			    .way_sel(victim_sel == i[$clog2(num_ways) - 1:0]),
			    .all_ways_ack(|w_hit),
			    /* CPU<->cache bus signals. */
			    .c_access(c_access),
			    .c_addr(c_addr),
			    .c_wr_val(c_wr_val),
			    .c_wr_en(c_wr_en),
			    .c_data(wc_data[i]),
			    .c_bytesel(c_bytesel),
			    .c_ack(wc_ack[i]),
			    .c_error(wc_error[i]),
			    /* CPU<->cache control signals. */
			    .c_inval(c_inval),
			    .c_flush(c_flush),
			    /* Debug control signals */
			    .dbg_inval(dbg_inval),
			    .dbg_flush(dbg_flush),
			    .dbg_complete(w_dbg_complete[i]),
			    .c_index(c_index),
			    .cacheop_complete(w_cacheop_complete[i]),
			    /* Cache<->memory signals. */
			    .m_access(wm_access[i]),
			    .m_addr(wm_addr[i]),
			    .m_wr_val(wm_wr_val[i]),
			    .m_wr_en(wm_wr_en[i]),
			    .m_bytesel(wm_bytesel[i]),
			    .m_data(m_data),
			    .m_ack(m_ack),
			    .m_error(m_error),
			    .tlb_valid(tlb_valid),
			    .tlb_phys(tlb_phys),
			    .access_ok(access_ok),
			    .filled(w_filled[i]),
			    .tlb_miss(tlb_miss));

end
endgenerate

always @(*) begin
	case (state)
	STATE_CACHED: begin
		if (c_access && !enabled)
			next_state = STATE_BYPASS;
		else if (enabled && tlb_complete && tlb_valid && tlb_phys[31]
			 && access_ok)
			next_state = STATE_BYPASS;
		else if (enabled && tlb_complete && tlb_valid &&
			 latched_access && latched_wr_en && ~|w_hit &&
			 access_ok)
			next_state = STATE_WRITE_MISS;
		else if ((c_flush || dbg_flush) && ~read_only)
			next_state = STATE_FLUSH;
		else
			next_state = STATE_CACHED;
	end
	STATE_WRITE_MISS: begin
		if (m_ack)
			next_state = STATE_CACHED;
		else
			next_state = STATE_WRITE_MISS;
	end
	STATE_BYPASS: begin
		if (m_ack)
			next_state = STATE_CACHED;
		else
			next_state = STATE_BYPASS;
	end
	STATE_FLUSH: begin
		next_state = cacheop_complete ? STATE_CACHED : STATE_FLUSH;
	end
	default: ;
	endcase
end


reg access_in_progress = 1'b0;

always @(posedge clk) begin
	if (c_ack || tlb_miss || c_error)
	        access_in_progress <= 1'b0;
	if (c_access && !tlb_miss)
	        access_in_progress <= 1'b1;
end

wire starting_request = c_access & (!access_in_progress || c_ack);

always @(*) begin
	bypass = 1'b0;
	bypass_access = 1'b0;

	tlb_translate = starting_request;
	tlb_virt = c_addr[29:10];

	if (state == STATE_BYPASS || state == STATE_WRITE_MISS) begin
		bypass_access = ~m_ack;
		bypass = 1'b1;
	end
end

always @(*) begin
	c_data = read_from_bypass ? bypass_data : 32'b0;
	for (way = 0; way < num_ways; way = way + 1)
		c_data = c_data | wc_data[way];
end

always @(posedge clk) begin
	bypass_data <= 32'b0;
	bypass_error <= 1'b0;
	bypass_ack <= 1'b0;
	read_from_bypass <= 1'b0;

	case (state)
	STATE_CACHED: begin
		completed_cacheops <= {num_ways{1'b0}};
	end
	STATE_FLUSH: begin
		completed_cacheops <= completed_cacheops | w_cacheop_complete;
	end
	STATE_BYPASS: begin
		bypass_data <= m_data;
		read_from_bypass <= 1'b1;
		bypass_ack <= m_ack;
		bypass_error <= m_error;
	end
	STATE_WRITE_MISS: begin
		bypass_ack <= m_ack;
		bypass_error <= m_error;
	end
	default: ;
	endcase
end

always @(posedge clk) begin
	latched_access <= c_access;

	if (c_access) begin
		latched_wr_en <= c_wr_en;
		latched_addr <= c_addr;
		latched_wr_val <= c_wr_val;
		latched_bytesel <= c_bytesel;
	end
end

always @(posedge clk) begin
	if (dbg_complete)
		completed_dbg_ops <= {num_ways{1'b0}};
	else
		completed_dbg_ops <= completed_dbg_ops | w_dbg_complete;
end

always @(posedge clk)
	state <= next_state;

always @(posedge clk) begin
	if ((enabled && |w_filled) || (completed_cacheops[victim_sel])) begin
		if (victim_sel == num_ways[$clog2(num_ways) - 1:0] - 1'b1)
			victim_sel <= {$clog2(num_ways){1'b0}};
		else
			victim_sel <= victim_sel + 1'b1;
	end
end

endmodule
