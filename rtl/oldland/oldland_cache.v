module oldland_cache(input wire		clk,
		     input wire		rst,
		     /* CPU<->cache bus signals. */
		     input wire		c_access,
		     input wire	[29:0]	c_addr,
		     output wire [31:0]	c_data,
		     output wire	c_ack,
		     output reg		c_error,
		     /* CPU<->cache control signals. */
		     input wire		c_inval,
		     input wire [CACHE_INDEX_BITS - 1:0] c_index,
		     /* Cache<->memory signals. */
		     output reg		m_access,
		     output wire [29:0]	m_addr,
		     input wire [31:0]	m_data,
		     input wire		m_ack,
		     input wire		m_error);

parameter cache_size		= 8192;
parameter cache_line_size	= 32;

localparam STATE_IDLE		= 3'b001;
localparam STATE_COMPARE	= 3'b010;
localparam STATE_FILL		= 3'b100;

localparam NR_CACHE_WORDS	= cache_size / 4;
localparam NR_CACHE_LINES	= cache_size / cache_line_size;

localparam CACHE_LINE_WORDS	= cache_line_size / 4;
localparam CACHE_LINE_WORD_BITS	= $clog2(CACHE_LINE_WORDS);
localparam CACHE_OFFSET_BITS	= $clog2(CACHE_LINE_WORDS);

localparam CACHE_INDEX_IDX	= CACHE_OFFSET_BITS;
localparam CACHE_INDEX_BITS	= $clog2(NR_CACHE_LINES);

localparam CACHE_TAG_IDX	= CACHE_INDEX_IDX + CACHE_INDEX_BITS;
localparam CACHE_TAG_BITS	= 30 - CACHE_INDEX_BITS - CACHE_OFFSET_BITS;

/*
 * Address signals.
 */
wire [CACHE_OFFSET_BITS - 1:0]	offset = c_addr[0+:CACHE_OFFSET_BITS];
wire [CACHE_INDEX_BITS - 1:0]	index = c_addr[CACHE_INDEX_IDX+:CACHE_INDEX_BITS];

reg [29:0]			latched_addr = 30'b0;
wire [CACHE_INDEX_BITS - 1:0]	latched_index = latched_addr[CACHE_INDEX_IDX+:CACHE_INDEX_BITS];
wire [CACHE_TAG_BITS - 1:0]	latched_tag = latched_addr[CACHE_TAG_IDX+:CACHE_TAG_BITS];

wire				tag_wr_en = word_offs == {CACHE_LINE_WORD_BITS{1'b1}} && m_ack;
wire				valid_mem_wr_en = rst | c_inval |
					(word_offs == {CACHE_LINE_WORD_BITS{1'b1}} && m_ack);
wire				valid_mem_wr_data = ~(rst | c_inval);
wire [CACHE_INDEX_BITS - 1:0]	valid_index = rst | c_inval ? c_index : index;
wire				data_ram_wr_en = state == STATE_FILL && m_ack;

/*
 * Per-access variables.
 */
wire [CACHE_OFFSET_BITS + CACHE_INDEX_BITS - 1:0] cache_addr = {index, offset};
wire [CACHE_TAG_BITS - 1:0]	cache_tag;

reg [CACHE_LINE_WORD_BITS - 1:0] word_offs = {CACHE_LINE_WORD_BITS{1'b0}};
wire [CACHE_LINE_WORD_BITS - 1:0] next_offs = word_offs + 1'b1;
wire [CACHE_LINE_WORD_BITS - 1:0] mem_offs = m_ack ? next_offs : word_offs;

wire line_filled		= word_offs == {CACHE_LINE_WORD_BITS{1'b1}} && m_ack;
assign m_addr			= {c_addr[29:CACHE_OFFSET_BITS], mem_offs};
wire tag_match			= cache_tag == latched_tag;
wire valid;
wire hit			= (tag_match && valid);
reg latched_access		= 1'b0;
reg fill_complete		= 1'b0;
assign c_ack			= (latched_access & hit) | fill_complete | c_error;

reg [2:0]			state = STATE_IDLE;
reg [2:0]			next_state = STATE_IDLE;

block_ram		#(.data_bits(CACHE_TAG_BITS),
			  .nr_entries(NR_CACHE_LINES))
			tag_ram(.clk(clk),
				.read_addr(index),
				.read_data(cache_tag),
				.wr_en(tag_wr_en),
				.write_addr(latched_index),
				.write_data(latched_tag));

block_ram		#(.data_bits(1),
			  .nr_entries(NR_CACHE_LINES))
			valid_ram(.clk(clk),
				  .read_addr(valid_index),
				  .read_data(valid),
				  .wr_en(valid_mem_wr_en),
				  .write_addr(valid_index),
				  .write_data(valid_mem_wr_data));

block_ram		#(.data_bits(32),
			  .nr_entries(cache_size / 4))
			data_ram(.clk(clk),
				 .read_addr(cache_addr),
				 .read_data(c_data),
				 .wr_en(data_ram_wr_en),
				 .write_addr({latched_index, word_offs}),
				 .write_data(m_data));

initial begin
	m_access = 1'b0;
	c_error = 1'b0;
end

always @(*) begin
	case (state)
	STATE_IDLE: next_state = c_access ? STATE_COMPARE : STATE_IDLE;
	STATE_COMPARE: next_state = !hit ? STATE_FILL :
		                    c_access ?  STATE_COMPARE : STATE_IDLE;
	STATE_FILL: next_state = m_error ? STATE_IDLE :
	                         line_filled ? STATE_IDLE : STATE_FILL;
	default: next_state = STATE_IDLE;
	endcase
end

always @(posedge clk) begin
	m_access <= 1'b0;
	fill_complete <= 1'b0;

	if (rst) begin
		word_offs <= {CACHE_LINE_WORD_BITS{1'b0}};
	end else if (state == STATE_FILL) begin
		m_access <= 1'b1;
		if (m_ack)
			word_offs <= next_offs;

		if (word_offs == {CACHE_LINE_WORD_BITS{1'b1}} && m_ack)
			fill_complete <= 1'b1;
	end
end

always @(posedge clk)
	c_error <= state == STATE_FILL && m_error;

always @(posedge clk)
	latched_access <= rst ? 1'b0 : c_access;

always @(posedge clk)
	latched_addr <= c_addr;

always @(posedge clk)
	state <= next_state;

endmodule
