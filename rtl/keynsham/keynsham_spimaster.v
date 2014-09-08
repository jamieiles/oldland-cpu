module keynsham_spimaster(input wire		clk,
			  /* Data bus. */
			  input wire		bus_access,
			  output wire		bus_cs,
			  input wire [29:0]	bus_addr,
			  input wire [31:0]	bus_wr_val,
			  input wire		bus_wr_en,
			  input wire [3:0]	bus_bytesel,
			  output reg		bus_error,
			  output reg		bus_ack,
			  output wire [31:0]	bus_data,
			  /* SPI bus. */
			  input wire		miso,
			  output wire		mosi,
			  output wire		sclk);

parameter	bus_address = 32'h0;
parameter	bus_size = 32'h0;

reg [31:0]	reg_rd_val = 32'b0;
reg		bus_rd_from_xfer_buf = 1'b0;
reg [31:0]	xfer_val_rotated = 32'b0;
assign		bus_data = bus_rd_from_xfer_buf ? xfer_val_rotated : reg_rd_val;

reg [12:0]	data_addr = {13{1'b0}};
reg [7:0]	data_val = 8'b0;
wire [7:0]	buf_rd_val;
wire		xfer_buf_cs = bus_addr[11];
wire		buf_wr_en = bus_access & bus_cs & bus_wr_en & xfer_buf_cs; /* 8192 byte offset. */

wire		xfer_start = write_xfer_ctrl_reg & bus_wr_val[GO_OFFSET] &
			!xfer_ctrl_reg[GO_OFFSET];
wire		xfer_complete;
reg		busy = 1'b0;

wire		do_reg_access = bus_access & bus_cs & !xfer_buf_cs;

wire		write_xfer_ctrl_reg = do_reg_access & bus_wr_en & bus_addr[1:0] == 2'b10;

reg [31:0]	ctrl_reg = 32'b0;
wire [8:0]	divider = ctrl_reg[8:0];
wire		loopback_enable = ctrl_reg[9];

reg [31:0]	xfer_ctrl_reg = 32'b0;
localparam	GO_OFFSET = 16;
localparam	BUSY_OFFSET = 17;
wire [12:0]	xfer_length = xfer_ctrl_reg[12:0];

wire		miso_internal = loopback_enable ? ~mosi : miso;

cs_gen		#(.address(bus_address), .size(bus_size))
		d_cs_gen(.bus_addr(bus_addr), .cs(bus_cs));

spisequencer	seq(.clk(clk),
		    /* Memory buffer signals. */
		    .buf_addr(data_addr),
		    .buf_wr_val(data_val),
		    .buf_rd_val(buf_rd_val),
		    .buf_wr_en(buf_wr_en),
		    /* SPI transfer control signals. */
		    .divider(divider),
		    .xfer_start(xfer_start),
		    .xfer_length(xfer_length),
		    .xfer_complete(xfer_complete),
		    /* SPI bus signals. */
		    .miso(miso_internal),
		    .mosi(mosi),
		    .sclk(sclk));

initial begin
	bus_error = 1'b0;
	bus_ack = 1'b0;
	reg_rd_val = 32'b0;
end

always @(*) begin
	case (bus_bytesel)
	4'b0001: begin
		data_addr = {bus_addr[10:0], 2'b00};
		data_val = bus_wr_val[7:0];
	end
	4'b0010: begin
		data_addr = {bus_addr[10:0], 2'b01};
		data_val = bus_wr_val[15:8];
	end
	4'b0100: begin
		data_addr = {bus_addr[10:0], 2'b10};
		data_val = bus_wr_val[23:16];
	end
	4'b1000: begin
		data_addr = {bus_addr[10:0], 2'b11};
		data_val = bus_wr_val[31:24];
	end
	default: begin
		data_addr = {bus_addr[10:0], 2'b00};
		data_val = bus_wr_val[7:0];
	end
	endcase
end

always @(posedge clk) begin
	reg_rd_val <= 32'b0;

	if (do_reg_access && !bus_wr_en) begin
		case (bus_addr[1:0])
		2'b00: reg_rd_val <= ctrl_reg;
		2'b10: reg_rd_val <= xfer_ctrl_reg | {14'b0, busy, 17'b0};
		default: reg_rd_val <= 32'b0;
		endcase
	end

	if (do_reg_access && bus_wr_en) begin
		case (bus_addr[1:0])
		2'b00: ctrl_reg <= bus_wr_val;
		2'b10: xfer_ctrl_reg <= bus_wr_val & 32'hfffeffff;
		default: ;
		endcase
	end

	if (bus_access && xfer_buf_cs && !bus_wr_en)
		reg_rd_val <= {24'b0, buf_rd_val};

	bus_ack <= bus_access && bus_cs;
end

always @(posedge clk) begin
	bus_rd_from_xfer_buf <= 1'b0;

	if (bus_access && bus_cs && !bus_wr_en && xfer_buf_cs)
		bus_rd_from_xfer_buf <= 1'b1;
end

always @(posedge clk) begin
	if (xfer_start)
		busy <= 1'b1;
	else if (xfer_complete)
		busy <= 1'b0;
end

always @(*) begin
	case (bus_bytesel)
	4'b0001: xfer_val_rotated = {24'b0, buf_rd_val};
	4'b0010: xfer_val_rotated = {16'b0, buf_rd_val, 8'b0};
	4'b0100: xfer_val_rotated = {8'b0, buf_rd_val, 16'b0};
	4'b1000: xfer_val_rotated = {buf_rd_val, 24'b0};
	default: xfer_val_rotated = 32'b0;
	endcase
end

endmodule
