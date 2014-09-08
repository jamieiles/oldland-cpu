module spisequencer(input wire				clk,
		    /* Memory buffer signals. */
		    input wire [addr_bits - 1:0]	buf_addr,
		    input wire [7:0]			buf_wr_val,
		    output wire [7:0]			buf_rd_val,
		    input wire				buf_wr_en,
		    /* SPI transfer control signals. */
		    input wire [8:0]			divider,
		    input wire				xfer_start,
		    input wire [addr_bits - 1:0]	xfer_length,
		    output reg				xfer_complete,
		    /* SPI bus signals. */
		    input wire				miso,
		    output wire				mosi,
		    output wire				sclk);

localparam		num_bytes = 8192;
localparam		addr_bits = $clog2(num_bytes);

localparam		STATE_IDLE	= 4'b0001;
localparam		STATE_XFER	= 4'b0010;
localparam		STATE_NEXT_BYTE	= 4'b0100;
localparam		STATE_COMPLETE	= 4'b1000;

reg [3:0]		state = STATE_IDLE;
reg [3:0]		next_state = STATE_IDLE;

wire [7:0]		seq_wr_val;
wire [7:0]		seq_rd_val;
reg			seq_wr_en = 1'b0;

reg			seq_xfer_start = 1'b0;
wire			seq_xfer_complete;

reg [addr_bits - 1:0]	bytes_xferred = {addr_bits{1'b0}};

spibuf	#(.num_bytes(num_bytes))
	xfer_buf(.clk(clk),
		 /* Host side buffer signals. */
		 .a_addr(buf_addr),
		 .a_wr_val(buf_wr_val),
		 .a_rd_val(buf_rd_val),
		 .a_wr_en(buf_wr_en),
		 /* Sequencer side buffer signals. */
		 .b_addr(bytes_xferred),
		 .b_wr_val(seq_wr_val),
		 .b_rd_val(seq_rd_val),
		 .b_wr_en(seq_wr_en));

spimaster	master(.clk(clk),
		       /* Control signals. */
		       .divider(divider),
		       .xfer_start(seq_xfer_start),
		       .xfer_complete(seq_xfer_complete),
		       .tx_data(seq_rd_val),
		       .rx_data(seq_wr_val),
		       /* SPI signals. */
		       .miso(miso),
		       .mosi(mosi),
		       .sclk(sclk));

initial xfer_complete = 1'b0;

always @(*) begin
	case (state)
	STATE_IDLE: begin
		next_state = xfer_start ? STATE_XFER : STATE_IDLE;
	end
	STATE_XFER: begin
		if (seq_xfer_complete)
			next_state = STATE_NEXT_BYTE;
		else
			next_state = STATE_XFER;
	end
	STATE_NEXT_BYTE: begin
		if (bytes_xferred == xfer_length)
			next_state = STATE_COMPLETE;
		else
			next_state = STATE_XFER;
	end
	STATE_COMPLETE: next_state = STATE_IDLE;
	default: ;
	endcase
end

always @(*) begin
	seq_wr_en = 1'b0;

	if (state == STATE_XFER && seq_xfer_complete)
		seq_wr_en = 1'b1;
end

always @(*)
	xfer_complete = (state == STATE_COMPLETE);

always @(*)
	seq_xfer_start = (state == STATE_XFER) & ~seq_xfer_complete;

always @(posedge clk)
	if (state == STATE_IDLE)
		bytes_xferred <= {addr_bits{1'b0}};
	else if (state == STATE_XFER && seq_xfer_complete)
		bytes_xferred <= bytes_xferred + 1'b1;

always @(posedge clk)
	state <= next_state;

endmodule
