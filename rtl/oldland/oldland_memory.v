module oldland_memory(input wire		clk,
		      input wire		rst,
		      input wire		load,
		      input wire		store,
		      input wire [31:0] 	addr,
		      input wire [31:0] 	mdr,
		      input wire		mem_wr_en,
		      input wire [1:0]		width,
		      input wire [31:0] 	wr_val,
		      input wire		update_rd,
		      input wire [3:0]		rd_sel,
		      output wire [31:0]	reg_wr_val,
		      output wire		update_rd_out,
		      output wire [3:0]		rd_sel_out,
		      output wire		complete,
		      output wire		data_abort,
		      /* Signals to data bus */
		      output wire [29:0]	d_addr,
		      output reg [3:0]		d_bytesel,
		      output wire		d_wr_en,
		      output reg [31:0]		d_wr_val,
		      input wire [31:0]		d_data,
		      output wire		d_access,
		      input wire		d_ack,
		      input wire		d_error,
		      /* Debug control signals. */
		      input wire		dbg_en,
		      input wire		dbg_access,
		      input wire		dbg_wr_en,
		      input wire [31:0]		dbg_addr,
		      input wire [1:0]		dbg_width,
		      input wire [31:0]		dbg_wr_val,
		      output wire [31:0]	dbg_rd_val,
		      output wire		dbg_compl,
		      input wire		i_valid,
		      output wire		busy);

reg [31:0]	wr_val_bypass;
reg		update_rd_bypass = 1'b0;
reg [31:0]	mem_rd_val;

wire [31:0]	wr_data = dbg_en ? dbg_wr_val : mdr;

wire [1:0]	byte_addr = dbg_en ? dbg_addr[1:0] : addr[1:0];
assign		d_addr = dbg_en ? dbg_addr[31:2] : addr[31:2];
assign		d_wr_en = dbg_en ? dbg_wr_en : mem_wr_en;
assign		d_access = dbg_en ? dbg_access : (load | store);

reg [3:0]	rd_sel_out_bypass = 4'b0;
reg [3:0]	mem_rd = 4'b0;
reg		mem_update_rd = 1'b0;
reg [31:0]	rd_mask = 32'b0;
wire [1:0]	mem_width = dbg_en ? dbg_width : width;

assign		reg_wr_val = complete ? mem_rd_val : wr_val_bypass;
assign		complete = d_ack | d_error;
assign		update_rd_out = complete && !dbg_en && !d_error ?
			mem_update_rd : update_rd_bypass;
assign		rd_sel_out = complete ? mem_rd : rd_sel_out_bypass;

assign		dbg_rd_val = mem_rd_val;
assign		dbg_compl = complete;
assign		data_abort = d_error;

assign		busy = load | store | update_rd_out;

initial begin
	wr_val_bypass = 32'b0;
	d_bytesel = 4'b0;
	d_wr_val = 32'b0;
	mem_rd_val = 32'b0;
end

always @(posedge clk) begin
	if (rst) begin
		update_rd_bypass <= 1'b0;
		mem_update_rd <= 1'b0;
	end else begin
		update_rd_bypass <= update_rd;
		wr_val_bypass <= wr_val;
		rd_sel_out_bypass <= rd_sel;

		if (load)
			mem_rd <= rd_sel;
		if (store || load)
			mem_update_rd <= load;
	end
end

/* Byte enables and rotated data write value. */
always @(*) begin
	case (mem_width)
	2'b10: begin
		rd_mask = {32{1'b1}};
		d_bytesel = 4'b1111;
		d_wr_val = wr_data;
		mem_rd_val = d_data & rd_mask;
	end
	2'b01: begin
		rd_mask = {{16{1'b0}}, {16{1'b1}}};
		d_bytesel = 4'b0011 << (byte_addr[1] * 2);
		d_wr_val = wr_data << (byte_addr[1] * 16);
		mem_rd_val = (d_data >> (byte_addr[1] * 16)) & rd_mask;
	end
	2'b00: begin
		rd_mask = {{24{1'b0}}, {8{1'b1}}};
		d_bytesel = 4'b0001 << byte_addr[1:0];
		d_wr_val = wr_data << (byte_addr[1:0] * 8);
		mem_rd_val = (d_data >> (byte_addr[1:0] * 8)) & rd_mask;
	end
	default: begin
		rd_mask = {32{1'b1}};
		d_bytesel = 4'b1111;
		d_wr_val = wr_data;
		mem_rd_val = d_data & rd_mask;
	end
	endcase
end

endmodule
