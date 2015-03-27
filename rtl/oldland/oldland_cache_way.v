/*
 * Instruction/data cache.
 * - Latch c_access, c_wr_en, these can go low over after the first cycle.
 * - If the address is cacheable, check the valid and dirty memories:
 *   - For a read:
 *     - if the valid bit is set and the tags match, then the data from the
 *     data ram will be valid, set c_ack, return to idle.
 *     - if the valid bit is set and the tags don't match:
 *       - if the dirty bit is set, write the line back to memory.
 *       - perform a line fill, finish.
 *     - if the valid bit is not set:
 *       - perform a line fill, finish.
 *   - For a write:
 *     - if the valid bit is set and the tags match:
 *       - set the dirty bit.
 *       - write the data to the cache line.
 *     - if the valid bit is not set or the tags don't match:
 *       - bypass the cache and write directly to memory.
 * The data ram should be dual-ported with a bypass.
 */
module oldland_cache_way(input wire		clk,
			 input wire		rst,
			 output wire		hit,
			 input wire		enabled,
			 input wire             way_sel,
			 input wire             all_ways_ack,
			 /* CPU<->cache bus signals. */
			 input wire		c_access,
			 input wire [29:0]	c_addr,
			 input wire [31:0]	c_wr_val,
			 input wire		c_wr_en,
			 output wire [31:0]	c_data,
			 input wire [3:0]	c_bytesel,
			 output wire		c_ack,
			 output wire		c_error,
			 /* CPU<->cache control signals. */
			 input wire		c_inval,
			 input wire		c_flush,
			 /* Debug control signals. */
			 input wire		dbg_inval,
			 input wire		dbg_flush,
			 output wire		dbg_complete,
			 input wire [CACHE_INDEX_BITS - 1:0] c_index,
			 output wire		cacheop_complete,
			 /* Cache<->memory signals. */
			 output wire		m_access,
			 output wire [29:0]	m_addr,
			 output wire [31:0]	m_wr_val,
			 output wire		m_wr_en,
			 output wire [3:0]	m_bytesel,
			 input wire [31:0]	m_data,
			 input wire		m_ack,
			 input wire		m_error,
			 input wire		tlb_valid,
			 input wire [31:12]	tlb_phys,
			 input wire		tlb_miss,
			 input wire		access_ok,
                         output reg             filled);

parameter way_size		= 4096;
parameter cache_line_size	= 32;
parameter read_only		= 1'b0;

wire [31:0]			cm_data;
reg [29:0]			cm_addr = 30'b0;
reg				cm_ack = 1'b0;
reg				cm_error = 1'b0;
reg				cm_access = 1'b0;
reg				cm_wr_en = 1'b0;
reg [31:0]			cm_wr_val = 32'b0;
reg [3:0]			cm_bytesel = 4'b0000;

reg				inval_complete = 1'b0;
reg				flush_complete = 1'b0;
reg 				dbg_inval_complete = 1'b0;
reg 				dbg_flush_complete = 1'b0;

assign				dbg_complete = dbg_inval_complete | dbg_flush_complete;
assign 				cacheop_complete = inval_complete | flush_complete;

assign				c_data = c_ack ? cm_data : 32'b0;
assign				c_ack = cm_ack | (state == STATE_COMPARE && hit) | cm_error;
assign				c_error = cm_error;

assign				m_access = cm_access;
assign				m_addr = cm_addr;
assign				m_wr_val = cm_wr_val;
assign				m_wr_en = cm_wr_en & ~read_only;
assign				m_bytesel = cm_bytesel;

localparam STATE_IDLE		= 5'b00001;
localparam STATE_COMPARE	= 5'b00010;
localparam STATE_EVICT		= 5'b00100;
localparam STATE_FILL		= 5'b01000;
localparam STATE_FLUSH		= 5'b10000;

localparam NR_CACHE_WORDS	= way_size / 4;
localparam NR_CACHE_LINES	= way_size / cache_line_size;

localparam CACHE_LINE_WORDS	= cache_line_size / 4;
localparam CACHE_OFFSET_BITS	= $clog2(CACHE_LINE_WORDS);

localparam CACHE_INDEX_IDX	= CACHE_OFFSET_BITS;
localparam CACHE_INDEX_BITS	= $clog2(NR_CACHE_LINES);

localparam CACHE_TAG_IDX	= CACHE_INDEX_IDX + CACHE_INDEX_BITS;
localparam CACHE_TAG_BITS	= 30 - CACHE_INDEX_BITS - CACHE_OFFSET_BITS;

reg [29:0]			latched_addr = 30'b0;
wire [29:0]                     phys_addr = {tlb_phys, latched_addr[9:0]};
wire [CACHE_TAG_BITS - 1:0]	phys_tag = phys_addr[CACHE_TAG_IDX+:CACHE_TAG_BITS];
wire [CACHE_INDEX_BITS - 1:0]	latched_index = latched_addr[CACHE_INDEX_IDX+:CACHE_INDEX_BITS];
wire [CACHE_OFFSET_BITS - 1:0]	latched_offset = latched_addr[0+:CACHE_OFFSET_BITS];
wire [CACHE_OFFSET_BITS - 1:0]	offset = c_addr[0+:CACHE_OFFSET_BITS];
wire [CACHE_INDEX_BITS - 1:0]	index = c_addr[CACHE_INDEX_IDX+:CACHE_INDEX_BITS];
wire [CACHE_TAG_BITS - 1:0]	cache_tag;
wire				valid;
reg [30 - CACHE_TAG_BITS - 1:0]	data_ram_read_addr = {30 - CACHE_TAG_BITS{1'b0}};
reg [CACHE_OFFSET_BITS - 1:0]	words_done = {CACHE_OFFSET_BITS{1'b0}};
reg				valid_mem_wr_en = 1'b0;
wire				tags_match = phys_tag == cache_tag;
assign				hit = tags_match && valid;
reg				latched_wr_en = 1'b0;
reg				latched_access = 1'b0;
reg [31:0]			latched_wr_val = 32'b0;
wire				valid_mem_wr_data = ~(rst | c_inval | dbg_inval);
reg [CACHE_INDEX_BITS - 1:0]	valid_index = {CACHE_INDEX_BITS{1'b0}};
reg				data_ram_wr_en = 1'b0;
reg				tag_wr_en = 1'b0;

wire [CACHE_INDEX_BITS - 1:0]	dirty_read_index = dbg_flush ? c_index : index;
wire [CACHE_INDEX_BITS - 1:0]	dirty_write_index = latched_index;
wire				dirty;
reg				dirty_wr_val = 1'b0;
reg				dirty_wr_en = 1'b0;

reg [4:0]			state = STATE_IDLE;
reg [4:0]			next_state = STATE_IDLE;
reg [3:0]			data_bytesel = 4'b0000;

initial begin
	filled = 1'b0;
end

block_ram		#(.data_bits(CACHE_TAG_BITS),
			  .nr_entries(NR_CACHE_LINES))
			tag_ram(.clk(clk),
				.read_addr(index),
				.read_data(cache_tag),
				.wr_en(tag_wr_en),
				.write_addr(latched_index),
				.write_data(phys_tag));

block_ram		#(.data_bits(1),
			  .nr_entries(NR_CACHE_LINES))
			valid_ram(.clk(clk),
				  .read_addr(valid_index),
				  .read_data(valid),
				  .wr_en(valid_mem_wr_en | dbg_inval | rst),
				  .write_addr(dbg_inval ? c_index : valid_index),
				  .write_data(valid_mem_wr_data));

block_ram		#(.data_bits(1),
			  .nr_entries(NR_CACHE_LINES))
			dirty_ram(.clk(clk),
				  .read_addr(dirty_read_index),
				  .read_data(dirty),
				  .wr_en(dirty_wr_en),
				  .write_addr(dirty_write_index),
				  .write_data(dirty_wr_val));

wire [CACHE_OFFSET_BITS - 1:0]	data_write_offset = latched_wr_en ?
					latched_offset : words_done;

cache_data_ram		#(.nr_entries(way_size / 4))
			data_ram(.clk(clk),
				 .read_addr(data_ram_read_addr),
				 .read_data(cm_data),
				 .wr_en(data_ram_wr_en),
				 .write_addr({latched_index, data_write_offset}),
				 .write_data(latched_wr_en ? latched_wr_val : m_data),
				 .bytesel(data_bytesel));

always @(*) begin
	case (state)
	STATE_IDLE: begin
		if (c_access && enabled && !tlb_miss)
			next_state = STATE_COMPARE;
		else if ((c_flush || dbg_flush) && ~read_only)
			next_state = STATE_FLUSH;
		else
			next_state = STATE_IDLE;
	end
	STATE_COMPARE: begin
		if (tlb_miss || !enabled)
			next_state = STATE_IDLE;
		else if (tlb_valid && tlb_phys[31] && access_ok)
			next_state = STATE_IDLE;
		else if (all_ways_ack && !c_access)
			next_state = STATE_IDLE;
		else if (way_sel && valid && !all_ways_ack && tlb_valid &&
			 !tags_match && !latched_wr_en && ~read_only &&
			 access_ok)
			next_state = STATE_EVICT;
		else if (way_sel && valid && !all_ways_ack && tlb_valid &&
			 !tags_match && !latched_wr_en && access_ok)
			next_state = STATE_FILL;
		else if (way_sel && !hit && !all_ways_ack && tlb_valid &&
			 !latched_wr_en && access_ok)
			next_state = STATE_FILL;
		else if (hit && c_access && latched_index == index) /* Pipelined accesses. */
			next_state = STATE_COMPARE;
		else
			next_state = STATE_IDLE;
	end
	STATE_FILL: begin
		if (m_error || line_complete)
			next_state = STATE_IDLE;
		else
			next_state = STATE_FILL;
	end
	STATE_FLUSH: begin
		if (m_error || line_complete || !valid || ~dirty)
			next_state = STATE_IDLE;
		else
			next_state = STATE_FLUSH;
	end
	STATE_EVICT: begin
		if (m_error || line_complete || ~dirty)
			next_state = STATE_FILL;
		else
			next_state = STATE_EVICT;
	end
	default: begin
		next_state = STATE_IDLE;
	end
	endcase
end

wire	line_complete = way_sel && m_ack &&
		words_done == CACHE_LINE_WORDS[CACHE_OFFSET_BITS - 1:0] - 1'b1;

task mem_write_word;
	input [29:0]	address;
begin
	cm_access = ~line_complete & valid & ~m_ack;
	cm_addr = address;
	cm_wr_en = ~line_complete;
	cm_wr_val = cm_wr_en ? cm_data : 32'b0;
	cm_bytesel = 4'b1111;
end
endtask

task set_dirty;
	input val;
begin
	dirty_wr_val = val;
	dirty_wr_en = 1'b1;
end
endtask

always @(*) begin
	tag_wr_en = 1'b0;
	valid_mem_wr_en = 1'b0;
	data_ram_wr_en = 1'b0;

	cm_wr_en = 1'b0;
	cm_addr = 30'b0;
	cm_bytesel = 4'b0000;
	cm_access = 1'b0;
	cm_wr_val = 32'b0;
	valid_index = {CACHE_INDEX_BITS{1'b0}};
	dirty_wr_en = 1'b0;
	dirty_wr_val = 1'b0;

	data_bytesel = 4'b1111;
	data_ram_read_addr = {30 - CACHE_TAG_BITS{1'b0}};

	filled = 1'b0;

	case (state)
	STATE_IDLE: begin
		data_ram_read_addr = {c_flush || dbg_flush ? c_index : index,
				      c_flush || dbg_flush ? {CACHE_OFFSET_BITS{1'b0}} : offset};

		valid_mem_wr_en = c_inval;
		valid_index = c_inval | dbg_inval | dbg_flush | rst ? c_index : index;
	end
	STATE_COMPARE: begin
		if (dbg_flush)
			data_ram_read_addr = {c_index, {CACHE_OFFSET_BITS{1'b0}}};
		else if (valid && !tags_match && !latched_wr_en)
			data_ram_read_addr = {index, {CACHE_OFFSET_BITS{1'b0}}};
		else
			/* Pipelined access. */
			data_ram_read_addr = {index, offset};

		if (latched_wr_en && hit && enabled)
			set_dirty(1'b1);

		valid_index = c_inval | dbg_inval | dbg_flush | rst ? c_index : index;

		data_ram_wr_en = enabled && latched_access && latched_wr_en && hit;
		data_bytesel = c_bytesel;
		cm_addr = enabled && !tlb_miss ? latched_addr : 30'b0;
	end
	STATE_FILL: begin
		data_ram_read_addr = {latched_index, latched_offset};
		cm_access = ~line_complete;
		cm_bytesel = 4'b1111;
		/*
		 * Pipeline read accesses to start reading the next word on
		 * finishing the previous word.
		 */
		cm_addr = {phys_tag, latched_index,
			   words_done + {{CACHE_OFFSET_BITS-1{1'b0}}, m_ack}};
		data_ram_wr_en = m_ack;
		tag_wr_en = 1'b1;
		valid_mem_wr_en = line_complete;
		valid_index = latched_index;

		if (line_complete) begin
			set_dirty(1'b0);
			filled = 1'b1;
		end
	end
	STATE_FLUSH, STATE_EVICT: begin
		data_ram_read_addr = {dbg_flush ? c_index : latched_index,
				      words_done + {{CACHE_OFFSET_BITS - 1{1'b0}}, m_ack}};
		valid_index = dbg_flush ? c_index : latched_index;
		if (way_sel && valid && dirty)
			mem_write_word({cache_tag, dbg_flush ? c_index : latched_index,
					words_done + {{CACHE_OFFSET_BITS - 1{1'b0}}, m_ack}});
		if (line_complete)
			set_dirty(1'b0);
	end
	default: ;
	endcase
end

always @(posedge clk) begin
	flush_complete <= state == STATE_FLUSH && (line_complete | ~valid | ~dirty);
	dbg_flush_complete <= state == STATE_FLUSH && (line_complete | ~valid | ~dirty);
end

always @(posedge clk) begin
	case (state)
	STATE_FILL: begin
		cm_ack <= line_complete;
		cm_error <= m_error;
	end
	STATE_FLUSH: begin
		cm_ack <= line_complete;
		cm_error <= m_error;
	end
	default: begin
		cm_ack <= 1'b0;
		cm_error <= 1'b0;
	end
	endcase
end

always @(posedge clk) begin
	if (state == STATE_FILL || state == STATE_FLUSH || state == STATE_EVICT) begin
		if (m_ack && way_sel)
			words_done <= words_done + 1'b1;
	end else begin
		words_done <= {CACHE_OFFSET_BITS{1'b0}};
	end
end

always @(posedge clk) begin
	latched_access <= c_access;
	if (c_access) begin
		latched_wr_en <= c_wr_en;
		latched_addr <= c_addr;
		latched_wr_val <= c_wr_val;
	end
end

always @(posedge clk) begin
	inval_complete <= c_inval;
	dbg_inval_complete <= dbg_inval;
end

always @(posedge clk)
	state <= next_state;

endmodule
