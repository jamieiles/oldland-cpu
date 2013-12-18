module oldland_cache(input wire		clk,
		     input wire		rst,
		     /* CPU<->cache bus signals. */
		     input wire		c_access,
		     input wire	[29:0]	c_addr,
		     output reg [31:0]	c_data,
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

parameter CACHE_SIZE		= 8192;
parameter CACHE_LINE_SIZE	= 32;

localparam STATE_IDLE		= 3'b001;
localparam STATE_COMPARE	= 3'b010;
localparam STATE_FILL		= 3'b100;

localparam NR_CACHE_WORDS	= CACHE_SIZE / 4;
localparam NR_CACHE_LINES	= CACHE_SIZE / CACHE_LINE_SIZE;

localparam CACHE_LINE_WORDS	= CACHE_LINE_SIZE / 4;
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

/*
 * Local memories.
 */
reg [NR_CACHE_LINES - 1:0]	valid_mem;
reg [31:0]			mem[(CACHE_SIZE / 4) - 1:0];
reg [CACHE_TAG_BITS - 1:0]	tag_mem[NR_CACHE_LINES - 1:0];
reg [CACHE_TAG_BITS - 1:0]	read_tag = {CACHE_TAG_BITS{1'b0}};

/*
 * Per-access variables.
 */
wire [CACHE_OFFSET_BITS + CACHE_INDEX_BITS - 1:0] cache_addr = {index, offset};
reg [CACHE_TAG_BITS - 1:0]	cache_tag = {CACHE_TAG_BITS{1'b0}};

reg [CACHE_LINE_WORD_BITS - 1:0] word_offs = {CACHE_LINE_WORD_BITS{1'b0}};
wire [CACHE_LINE_WORD_BITS - 1:0] next_offs = word_offs + 1'b1;
wire [CACHE_LINE_WORD_BITS - 1:0] mem_offs = m_ack ? next_offs : word_offs;

wire line_filled		= word_offs == {CACHE_LINE_WORD_BITS{1'b1}} && m_ack;
assign m_addr			= {c_addr[29:CACHE_OFFSET_BITS], mem_offs};
wire tag_match			= cache_tag == latched_tag;
wire hit			= (tag_match && valid_mem[latched_index]);
reg latched_access		= 1'b0;
reg fill_complete		= 1'b0;
assign c_ack			= (latched_access & hit) | fill_complete | c_error;

reg [2:0]			state = STATE_IDLE;
reg [2:0]			next_state = STATE_IDLE;

integer i;

initial begin
	for (i = 0; i < NR_CACHE_LINES; i = i + 1) begin
		valid_mem[i] = 1'b0;
		tag_mem[i] = {CACHE_TAG_BITS{1'b0}};
	end
	c_data = 32'b0;
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
		if (m_ack) begin
			word_offs <= next_offs;
			mem[{latched_index, word_offs}] <= m_data;
		end

		if (word_offs == {CACHE_LINE_WORD_BITS{1'b1}} && m_ack)
			fill_complete <= 1'b1;
	end
end

always @(posedge clk) begin
	if (rst || c_inval)
		valid_mem[c_index] <= 1'b0;
	else if (word_offs == {CACHE_LINE_WORD_BITS{1'b1}} && m_ack)
		valid_mem[latched_index] <= 1'b1;
end

always @(posedge clk)
	c_error <= state == STATE_FILL && m_error;

always @(posedge clk)
	latched_access <= rst ? 1'b0 : c_access;

always @(posedge clk)
	latched_addr <= c_addr;

always @(posedge clk)
	state <= next_state;

always @(posedge clk)
	if (state == STATE_FILL && word_offs == offset && m_ack)
		c_data <= m_data;
	else
		c_data <= mem[cache_addr];

always @(posedge clk) begin
	read_tag <= tag_mem[index];

	if (word_offs == {CACHE_LINE_WORD_BITS{1'b1}} && m_ack)
		tag_mem[latched_index] <= latched_tag;
end

always @(posedge clk)
	if (word_offs == {CACHE_LINE_WORD_BITS{1'b1}} && m_ack)
		cache_tag <= latched_tag;
	else
		cache_tag <= read_tag;

endmodule
