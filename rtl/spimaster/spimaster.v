/*
 * Integration:
 *
 *  - spisequencer:
 *    - block ram containing tx bytes + receive buffer, overwrite tx bytes
 *    with receive bytes
 *    - sequencer has a state machine to perform the required number of byte
 *    transfers.
 *
 * - spicontroller:
 *   - integrates spisequencer and provides memory mapped interface.
 *   - outputs chip selects to outside.
 */

/*
 * Simple SPI master.  Chip selects are provided at a higher level, other
 * signals are generated internally.
 *
 * Operates in SPI mode 0.
 *
 * Transfer starts on low->high transition of xfer_start, xfer_complete goes
 * high when a byte transfer has completed.
 *
 * tx_data is transmitted LSB first onto mosi, data is shifted into rx_data
 * from miso.
 */
module spimaster(input wire		clk,
		 /* Control signals. */
		 input wire [8:0]	divider,
		 input wire		xfer_start,
		 output reg		xfer_complete,
		 input wire [7:0]	tx_data,
		 output reg [7:0] 	rx_data,
		 /* SPI signals. */
		 input wire		miso,
		 output reg		mosi,
		 output reg		sclk);

reg [8:0]	clk_counter = 9'b0;

reg [3:0]	xfer_bit = 4'b0;

wire		sclk_rising = ~sclk & ~|clk_counter;
wire		sclk_falling = sclk & ~|clk_counter;

localparam	STATE_IDLE	= 3'b001;
localparam	STATE_XFER	= 3'b010;
localparam	STATE_COMPLETE	= 3'b100;

reg [2:0]	state = STATE_IDLE;
reg [2:0]	next_state = STATE_IDLE;

initial begin
	sclk = 1'b0;
	rx_data = 8'b0;
	mosi = 1'b1;
	xfer_complete = 1'b0;
end

always @(*) begin
	case (state)
	STATE_IDLE: begin
		next_state = xfer_start ? STATE_XFER : STATE_IDLE;
	end
	STATE_XFER: begin
		if (~|clk_counter && xfer_bit[3] && sclk)
			next_state = STATE_COMPLETE;
		else
			next_state = STATE_XFER;
	end
	STATE_COMPLETE: begin
		next_state = STATE_IDLE;
	end
	default: ;
	endcase
end

always @(posedge clk) begin
	xfer_complete <= 1'b0;

	case (state)
	STATE_IDLE: begin
		mosi <= xfer_start ? tx_data[7] : 1'b1;
		xfer_bit <= 4'b0;
	end
	STATE_XFER: begin
		if (sclk_falling && ~xfer_bit[3])
			mosi <= tx_data[~xfer_bit[2:0]];
		else if (sclk_rising) begin
			xfer_bit <= xfer_bit + 1'b1;
			rx_data[~xfer_bit[2:0]] <= miso;
		end
	end
	STATE_COMPLETE: begin
		xfer_complete <= 1'b1;
		mosi <= 1'b1;
	end
	default: ;
	endcase
end

always @(posedge clk) begin
	case (state)
	STATE_IDLE: begin
		sclk <= 1'b0;
		clk_counter <= divider;
	end
	STATE_XFER: begin
		clk_counter <= clk_counter - 1'b1;
		if (~|clk_counter) begin
			clk_counter <= divider;
			sclk <= ~sclk;
		end
	end
	STATE_COMPLETE: begin
		sclk <= 1'b0;
	end
	default: ;
	endcase
end

always @(posedge clk)
	state <= next_state;

endmodule
