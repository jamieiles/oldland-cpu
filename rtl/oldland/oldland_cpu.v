module oldland_cpu(input wire		clk,
		   output wire		running,
		   input wire		irq_req,
		   /* Instruction bus. */
		   output wire		i_access,
		   output wire [29:0]	i_addr,
		   input wire [31:0]	i_data,
		   input wire		i_ack,
		   input wire		i_error,
		   /* Data bus. */
		   output wire [29:0]	d_addr,
		   output wire [3:0]	d_bytesel,
		   output wire		d_wr_en,
		   output wire [31:0]	d_wr_val,
		   input wire [31:0]	d_data,
		   output wire		d_access,
		   input wire		d_ack,
		   input wire		d_error,
		   /* Debug control signals. */
		   input wire		dbg_clk,
		   input wire [1:0]	dbg_addr,
		   input wire [31:0]	dbg_din,
		   output wire [31:0]	dbg_dout,
		   input wire		dbg_wr_en,
		   input wire		dbg_req,
		   output wire		dbg_ack,
		   output wire		dbg_rst);

/* Debug control signals. */
wire		cpu_run;
wire		cpu_stopped;
wire [3:0]	dbg_reg_sel;
wire [31:0]	dbg_reg_wr_val;
wire [31:0]	dbg_reg_val;
wire		dbg_reg_wr_en;
wire [2:0]	dbg_cr_sel;
wire [31:0]	dbg_cr_val;
wire [31:0]	dbg_cr_wr_val;
wire		dbg_cr_wr_en;
wire [31:0]	dbg_pc;
wire [31:0]	dbg_pc_wr_val;
wire		dbg_pc_wr_en;
wire [31:0]	dbg_mem_addr;
wire [1:0]	dbg_mem_width;
wire [31:0]	dbg_mem_wr_val;
wire [31:0]	dbg_mem_rd_val;
wire		dbg_mem_wr_en;
wire		dbg_mem_access;
wire		dbg_mem_compl;
wire		dbg_cache_sync;

/* CPU<->I$ signals. */
wire		ic_access;
wire [29:0]	ic_addr;
wire [31:0]	ic_data;
wire		ic_ack;
wire		ic_error;

cache			icache(.clk(clk),
			       .rst(dbg_rst),
			       .c_access(ic_access),
			       .c_addr(ic_addr),
			       .c_data(ic_data),
			       .c_ack(ic_ack),
			       .c_error(ic_error),
			       .ctrl_inval(dbg_cache_sync),
			       .m_access(i_access),
			       .m_addr(i_addr),
			       .m_data(i_data),
			       .m_ack(i_ack),
			       .m_error(i_error));

oldland_debug		debug(.clk(clk),
		              /* Controller to debug signals. */
		              .dbg_clk(dbg_clk),
		              .addr(dbg_addr),
		              .din(dbg_din),
		              .dout(dbg_dout),
		              .wr_en(dbg_wr_en),
		              .req(dbg_req),
		              .ack(dbg_ack),
		              /* Execution control. */
		              .run(cpu_run),
		              .stopped(cpu_stopped),
		              /* Memory debug. */
		              .mem_addr(dbg_mem_addr),
		              .mem_width(dbg_mem_width),
		              .mem_wr_val(dbg_mem_wr_val),
		              .mem_rd_val(dbg_mem_rd_val),
		              .mem_wr_en(dbg_mem_wr_en),
		              .mem_access(dbg_mem_access),
		              .mem_compl(dbg_mem_compl),
		              /* Register access. */
		              .dbg_reg_sel(dbg_reg_sel),
		              .dbg_reg_wr_val(dbg_reg_wr_val),
		              .dbg_reg_val(dbg_reg_val),
		              .dbg_reg_wr_en(dbg_reg_wr_en),
		              .dbg_cr_sel(dbg_cr_sel),
		              .dbg_cr_wr_val(dbg_cr_wr_val),
		              .dbg_cr_val(dbg_cr_val),
		              .dbg_cr_wr_en(dbg_cr_wr_en),
		              .dbg_pc(dbg_pc),
		              .dbg_pc_wr_val(dbg_pc_wr_val),
		              .dbg_pc_wr_en(dbg_pc_wr_en),
		              /* Reset. */
		              .dbg_rst(dbg_rst),
			      /* Cache maintenance. */
			      .dbg_cache_sync(dbg_cache_sync));

oldland_pipeline	pipeline(.clk(clk),
				 .irq_req(irq_req),
				 /* Instruction bus. */
				 .i_access(ic_access),
				 .i_addr(ic_addr),
				 .i_data(ic_data),
				 .i_ack(ic_ack),
				 .i_error(ic_error),
				 /* Data bus. */
				 .d_addr(d_addr),
				 .d_bytesel(d_bytesel),
				 .d_wr_en(d_wr_en),
				 .d_wr_val(d_wr_val),
				 .d_data(d_data),
				 .d_access(d_access),
				 .d_ack(d_ack),
				 .d_error(d_error),
				 /* Debug signals. */
				 .run(cpu_run),
				 .stopped(cpu_stopped),
				 /* Memory debug. */
				 .dbg_mem_addr(dbg_mem_addr),
				 .dbg_mem_width(dbg_mem_width),
				 .dbg_mem_wr_val(dbg_mem_wr_val),
				 .dbg_mem_rd_val(dbg_mem_rd_val),
				 .dbg_mem_wr_en(dbg_mem_wr_en),
				 .dbg_mem_access(dbg_mem_access),
				 .dbg_mem_compl(dbg_mem_compl),
				 /* Register access. */
				 .dbg_reg_sel(dbg_reg_sel),
				 .dbg_reg_wr_val(dbg_reg_wr_val),
				 .dbg_reg_val(dbg_reg_val),
				 .dbg_reg_wr_en(dbg_reg_wr_en),
				 .dbg_cr_sel(dbg_cr_sel),
				 .dbg_cr_wr_val(dbg_cr_wr_val),
				 .dbg_cr_val(dbg_cr_val),
				 .dbg_cr_wr_en(dbg_cr_wr_en),
				 .dbg_pc(dbg_pc),
				 .dbg_pc_wr_val(dbg_pc_wr_val),
				 .dbg_pc_wr_en(dbg_pc_wr_en),
				 /* Reset. */
				 .dbg_rst(dbg_rst));

endmodule
