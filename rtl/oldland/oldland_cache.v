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
module oldland_cache(input wire		clk,
		     input wire		rst,
		     /* CPU<->cache bus signals. */
		     input wire		c_access,
		     input wire	[29:0]	c_addr,
		     input wire [31:0]	c_wr_val,
		     input wire		c_wr_en,
		     output wire [31:0]	c_data,
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
		     input wire		cacheable_addr);

parameter cache_size		= 8192;
parameter cache_line_size	= 32;

reg [31:0]			bypass_data = 32'b0;

wire [31:0]			cm_data;
reg [29:0]			cm_addr = 30'b0;
reg				cm_ack = 1'b0;
reg				cm_error = 1'b0;
reg				cm_access = 1'b0;
reg				cm_wr_en = 1'b0;
reg [31:0]			cm_wr_val = 32'b0;
reg [3:0]			cm_bytesel = 4'b1111;

reg				inval_complete = 1'b0;
reg				flush_complete = 1'b0;
reg 				dbg_inval_complete = 1'b0;
reg 				dbg_flush_complete = 1'b0;

assign				dbg_complete = dbg_inval_complete | dbg_flush_complete;
assign 				cacheop_complete = inval_complete | flush_complete;

assign				c_data = cm_data | bypass_data;
assign				c_ack = cm_ack | (state == STATE_COMPARE && hit) | cm_error;
assign				c_error = cm_error;

assign				m_access = cm_access;
assign				m_addr = cm_addr;
assign				m_wr_val = cm_wr_val;
assign				m_wr_en = cm_wr_en;
assign				m_bytesel = cm_bytesel;

localparam STATE_IDLE		= 7'b0000001;
localparam STATE_COMPARE	= 7'b0000010;
localparam STATE_BYPASS		= 7'b0000100;
localparam STATE_EVICT		= 7'b0001000;
localparam STATE_FILL		= 7'b0010000;
localparam STATE_FLUSH		= 7'b0100000;
localparam STATE_WRITE_MISS	= 7'b1000000;

localparam NR_CACHE_WORDS	= cache_size / 4;
localparam NR_CACHE_LINES	= cache_size / cache_line_size;

localparam CACHE_LINE_WORDS	= cache_line_size / 4;
localparam CACHE_LINE_WORD_BITS	= $clog2(CACHE_LINE_WORDS);
localparam CACHE_OFFSET_BITS	= $clog2(CACHE_LINE_WORDS);

localparam CACHE_INDEX_IDX	= CACHE_OFFSET_BITS;
localparam CACHE_INDEX_BITS	= $clog2(NR_CACHE_LINES);

localparam CACHE_TAG_IDX	= CACHE_INDEX_IDX + CACHE_INDEX_BITS;
localparam CACHE_TAG_BITS	= 30 - CACHE_INDEX_BITS - CACHE_OFFSET_BITS;

reg [29:0]			latched_addr = 30'b0;
wire [CACHE_INDEX_BITS - 1:0]	latched_index = latched_addr[CACHE_INDEX_IDX+:CACHE_INDEX_BITS];
wire [CACHE_OFFSET_BITS - 1:0]	latched_offset = latched_addr[0+:CACHE_OFFSET_BITS];
wire [CACHE_TAG_BITS - 1:0]	latched_tag = latched_addr[CACHE_TAG_IDX+:CACHE_TAG_BITS];
wire [CACHE_OFFSET_BITS - 1:0]	offset = c_addr[0+:CACHE_OFFSET_BITS];
wire [CACHE_INDEX_BITS - 1:0]	index = c_addr[CACHE_INDEX_IDX+:CACHE_INDEX_BITS];
wire [CACHE_TAG_BITS - 1:0]	cache_tag;
wire				valid;
reg [30 - CACHE_TAG_BITS - 1:0]	data_ram_read_addr = {30 - CACHE_TAG_BITS{1'b0}};
reg [CACHE_OFFSET_BITS:0]	words_done = {CACHE_OFFSET_BITS + 1{1'b0}};
reg				valid_mem_wr_en = 1'b0;
wire				tags_match = latched_tag == cache_tag;
wire				hit = tags_match && valid;
reg				latched_wr_en = 1'b0;
reg				latched_access = 1'b0;
reg [3:0]			latched_bytesel = 4'b0;
reg [31:0]			latched_wr_val = 32'b0;
wire				valid_mem_wr_data = ~(rst | c_inval | dbg_inval);
reg [CACHE_INDEX_BITS - 1:0]	valid_index = {CACHE_INDEX_BITS{1'b0}};
reg				data_ram_wr_en = 1'b0;
reg				tag_wr_en = 1'b0;

reg [6:0]			state = STATE_IDLE;
reg [6:0]			next_state = STATE_IDLE;
reg [3:0]			data_bytesel = 4'b0000;

block_ram		#(.data_bits(CACHE_TAG_BITS),
			  .nr_entries(NR_CACHE_LINES))
			tag_ram(.clk(clk),
				.read_addr(index),
				.read_data(cache_tag),
				.wr_en(tag_wr_en),
				.write_addr(index),
				.write_data(latched_tag));

block_ram		#(.data_bits(1),
			  .nr_entries(NR_CACHE_LINES))
			valid_ram(.clk(clk),
				  .read_addr(valid_index),
				  .read_data(valid),
				  .wr_en(valid_mem_wr_en | dbg_inval | rst),
				  .write_addr(dbg_inval ? c_index : valid_index),
				  .write_data(valid_mem_wr_data));

wire [CACHE_OFFSET_BITS - 1:0]	data_write_offset = latched_wr_en ?
					latched_offset : words_done[CACHE_OFFSET_BITS - 1:0];

cache_data_ram		#(.nr_entries(cache_size / 4))
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
		if (c_access && !cacheable_addr)
			next_state = STATE_BYPASS;
		else if (c_access)
			next_state = STATE_COMPARE;
		else if (c_flush || dbg_flush)
			next_state = STATE_FLUSH;
		else
			next_state = STATE_IDLE;
	end
	STATE_COMPARE: begin
		if (valid && !tags_match && !latched_wr_en)
			next_state = STATE_EVICT;
		else if (!hit && !latched_wr_en)
			next_state = STATE_FILL;
		else if (!hit && latched_wr_en)
			next_state = STATE_WRITE_MISS;
		else if (hit && c_access && latched_index == index) /* Pipelined accesses. */
			next_state = STATE_COMPARE;
		else
			next_state = STATE_IDLE;
	end
	STATE_BYPASS: begin
		next_state = m_ack ? STATE_IDLE : STATE_BYPASS;
	end
	STATE_WRITE_MISS: begin
		next_state = m_ack ? STATE_IDLE : STATE_WRITE_MISS;
	end
	STATE_FILL: begin
		if (m_error || line_complete)
			next_state = STATE_IDLE;
		else
			next_state = STATE_FILL;
	end
	STATE_FLUSH: begin
		if (m_error || line_complete || !valid)
			next_state = STATE_IDLE;
		else
			next_state = STATE_FLUSH;
	end
	STATE_EVICT: begin
		if (m_error || line_complete)
			next_state = STATE_FILL;
		else
			next_state = STATE_EVICT;
	end
	default: begin
		next_state = STATE_IDLE;
	end
	endcase
end

wire	line_complete = m_ack &&
		words_done == CACHE_LINE_WORDS[CACHE_OFFSET_BITS:0] - 1'b1;

task mem_write_word;
	input [29:0]	address;
	input [31:0]	data;
begin
	cm_access = ~line_complete & valid & ~m_ack;
	cm_addr = address;
	cm_wr_en = ~line_complete;
	cm_wr_val = cm_data;
end
endtask

always @(*) begin
	tag_wr_en = 1'b0;
	valid_mem_wr_en = 1'b0;
	data_ram_wr_en = 1'b0;

	cm_wr_en = 1'b0;
	cm_addr = 30'b0;
	cm_bytesel = 4'b1111;
	cm_access = 1'b0;
	cm_wr_val = 32'b0;
	valid_index = {CACHE_INDEX_BITS{1'b0}};

	data_bytesel = 4'b1111;
	data_ram_read_addr = {30 - CACHE_TAG_BITS{1'b0}};

	case (state)
	STATE_IDLE: begin
		data_ram_read_addr = {c_flush || dbg_flush ? c_index : index,
				      c_flush || dbg_flush ? {CACHE_OFFSET_BITS{1'b0}} : offset};

		if (cacheable_addr) begin
			valid_mem_wr_en = c_inval;
			valid_index = c_inval | dbg_inval | dbg_flush | rst ? c_index : index;
		end
	end
	STATE_COMPARE: begin
		if (dbg_flush)
			data_ram_read_addr = {c_index, {CACHE_OFFSET_BITS{1'b0}}};
		else if (valid && !tags_match && !latched_wr_en)
			data_ram_read_addr = {index, {CACHE_OFFSET_BITS{1'b0}}};
		else
			/* Pipelined access. */
			data_ram_read_addr = {index, offset};
		data_ram_wr_en = latched_access && latched_wr_en && hit;
		data_bytesel = c_bytesel;
		cm_addr = latched_addr;

	end
	STATE_FILL: begin
		data_ram_read_addr = {latched_index, latched_offset};
		cm_access = ~line_complete;
		/*
		 * Pipeline read accesses to start reading the next word on
		 * finishing the previous word.
		 */
		cm_addr = {latched_tag, latched_index,
			   words_done[CACHE_OFFSET_BITS - 1:0] + {{CACHE_OFFSET_BITS-1{1'b0}}, m_ack}};
		data_ram_wr_en = m_ack;
		tag_wr_en = 1'b1;
		valid_mem_wr_en = line_complete;
		valid_index = latched_index;
	end
	STATE_FLUSH: begin
		data_ram_read_addr = {dbg_flush ? c_index : latched_index,
				      words_done[CACHE_OFFSET_BITS - 1:0] + 1'b1};
		valid_index = dbg_flush ? c_index : latched_index;
		if (valid)
			mem_write_word({cache_tag, dbg_flush ? c_index : latched_index,
					words_done[CACHE_OFFSET_BITS - 1:0] + {{CACHE_OFFSET_BITS - 1{1'b0}}, m_ack}}, cm_data);
	end
	STATE_EVICT: begin
		data_ram_read_addr = {dbg_flush ? c_index : latched_index,
				      words_done[CACHE_OFFSET_BITS - 1:0] + 1'b1};
		mem_write_word({cache_tag, dbg_flush ? c_index : latched_index,
				words_done[CACHE_OFFSET_BITS - 1:0] + {{CACHE_OFFSET_BITS - 1{1'b0}}, m_ack}}, cm_data);
	end
	STATE_BYPASS: begin
		cm_addr = latched_addr;
		cm_wr_val = latched_wr_val;
		cm_wr_en = latched_wr_en;
		cm_bytesel = latched_bytesel;
		cm_access = ~m_ack;
	end
	STATE_WRITE_MISS: begin
		cm_access = ~m_ack;
		cm_addr = latched_addr;
		cm_wr_en = 1'b1;
		cm_wr_val = latched_wr_val;
		cm_bytesel = c_bytesel;
	end
	default: ;
	endcase
end

always @(posedge clk) begin
	flush_complete <= state == STATE_FLUSH && (line_complete | ~valid);
	dbg_flush_complete <= state == STATE_FLUSH && (line_complete | ~valid);
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
	STATE_BYPASS: begin
		cm_ack <= m_ack;
		cm_error <= m_error;
	end
	STATE_WRITE_MISS: begin
		cm_ack <= m_ack;
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
		if (m_ack)
			words_done <= words_done + 1'b1;
	end else begin
		words_done <= {CACHE_OFFSET_BITS + 1{1'b0}};
	end
end

always @(posedge clk) begin
	bypass_data <= state == STATE_BYPASS ? m_data : 32'b0;
end

always @(posedge clk) begin
	latched_access <= c_access;
	latched_wr_en <= c_wr_en;
	latched_addr <= c_addr;
	latched_wr_val <= c_wr_val;
	latched_bytesel <= c_bytesel;
end

always @(posedge clk) begin
	inval_complete <= c_inval;
	dbg_inval_complete <= dbg_inval;
end

always @(posedge clk)
	state <= next_state;

endmodule
