module oldland_cpu(input wire		clk,
		   output wire		running,
		   input wire		irq_req,
		   input wire		rst_req,
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

parameter	icache_size = 8192;
parameter	icache_line_size = 32;
parameter	icache_num_ways = 2;
parameter	dcache_size = 8192;
parameter	dcache_line_size = 32;
parameter	dcache_num_ways = 2;
parameter	cpuid_manufacturer = 16'h4a49;
parameter	cpuid_model = 16'h0001;
parameter	cpu_clock_speed = 32'd50000000;

localparam	icache_nr_lines = (icache_size / icache_num_ways) / icache_line_size;
localparam	icache_idx_bits = $clog2(icache_nr_lines);
localparam	dcache_nr_lines = (dcache_size / dcache_num_ways) / dcache_line_size;
localparam	dcache_idx_bits = $clog2(dcache_nr_lines);

/* CPU<->I$ signals. */
wire		ic_access;
wire [29:0]	ic_addr;
wire [31:0]	ic_data;
wire		ic_ack;
wire		ic_error;
wire		pipeline_icache_inval;
wire		i_cache_enabled;
wire [icache_idx_bits - 1:0] pipeline_icache_idx;

/* CPU<->D$ signals. */
wire		dc_access;
wire [29:0]	dc_addr;
wire [31:0]	dc_data;
wire [31:0]	dc_wr_val;
wire		dc_wr_en;
wire [3:0]	dc_bytesel;
wire		dc_ack;
wire		dc_error;
wire		d_cache_enabled;
wire		pipeline_dcache_inval;
wire		pipeline_dcache_flush;
wire [dcache_idx_bits - 1:0] pipeline_dcache_idx;

/* Debug control signals. */
wire		cpu_run;
wire		cpu_stopped;
wire		dbg_en;
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
wire [icache_idx_bits - 1:0] dbg_icache_idx;
wire [dcache_idx_bits - 1:0] dbg_dcache_idx;
wire [icache_idx_bits - 1:0] icache_idx = dbg_en | dbg_rst ? dbg_icache_idx : pipeline_icache_idx;
wire [dcache_idx_bits - 1:0] dcache_idx = dbg_en | dbg_rst ? dbg_dcache_idx : pipeline_dcache_idx;
wire		dbg_icache_inval;
wire		dbg_dcache_inval;
wire		dbg_dcache_flush;
wire		dbg_icache_complete;
wire		dbg_dcache_complete;
wire [2:0]	dbg_cpuid_sel;
wire            dbg_bkpt_hit;
wire		i_cacheop_complete;
wire		d_cacheop_complete;

/* CPUID signals. */
wire [2:0]	cpu_cpuid_sel;
wire [2:0]	cpuid_sel = dbg_en ? dbg_cpuid_sel : cpu_cpuid_sel;
wire [31:0]	cpuid_val;

oldland_cpuid		#(.cpuid_manufacturer(cpuid_manufacturer),
			  .cpuid_model(cpuid_model),
			  .cpu_clock_speed(cpu_clock_speed),
			  .icache_size(icache_size),
			  .icache_line_size(icache_line_size),
                          .icache_num_ways(icache_num_ways),
			  .dcache_size(dcache_size),
			  .dcache_line_size(dcache_line_size),
                          .dcache_num_ways(dcache_num_ways))
			oldland_cpuid(.reg_sel(cpuid_sel),
				      .val(cpuid_val));

oldland_cache		#(.cache_size(icache_size),
			  .cache_line_size(icache_line_size),
			  .num_ways(icache_num_ways),
			  .read_only(1'b1))
			icache(.clk(clk),
			       .rst(dbg_rst),
			       .enabled(i_cache_enabled),
			       .c_access(ic_access),
			       .c_addr(ic_addr),
			       .c_wr_val(32'b0),
			       .c_wr_en(1'b0),
			       .c_bytesel(4'b1111),
			       .c_data(ic_data),
			       .c_ack(ic_ack),
			       .c_error(ic_error),
			       .c_inval(pipeline_icache_inval),
			       .c_flush(1'b0),
			       .dbg_inval(dbg_icache_inval),
			       .dbg_flush(1'b0),
			       .dbg_complete(dbg_icache_complete),
			       .c_index(icache_idx),
			       .cacheop_complete(i_cacheop_complete),
			       .m_access(i_access),
			       .m_addr(i_addr),
			       .m_data(i_data),
			       .m_ack(i_ack),
			       .m_error(i_error),
			       /* verilator lint_off PINNOCONNECT */
			       .m_bytesel(),
			       .m_wr_en(),
			       .m_wr_val(),
			       /* verilator lint_on PINNOCONNECT */
			       .cacheable_addr(1'b1));

oldland_cache		#(.cache_size(dcache_size),
			  .cache_line_size(dcache_line_size),
			  .num_ways(dcache_num_ways))
			dcache(.clk(clk),
			       .rst(dbg_rst),
			       .enabled(d_cache_enabled),
			       .c_access(dc_access),
			       .c_addr(dc_addr),
			       .c_wr_val(dc_wr_val),
			       .c_wr_en(dc_wr_en),
			       .c_bytesel(dc_bytesel),
			       .c_data(dc_data),
			       .c_ack(dc_ack),
			       .c_error(dc_error),
			       .c_inval(pipeline_dcache_inval),
			       .c_flush(pipeline_dcache_flush),
			       .dbg_inval(dbg_dcache_inval),
			       .dbg_flush(dbg_dcache_flush),
			       .dbg_complete(dbg_dcache_complete),
			       .c_index(dcache_idx),
			       .cacheop_complete(d_cacheop_complete),
			       .m_access(d_access),
			       .m_addr(d_addr),
			       .m_data(d_data),
			       .m_ack(d_ack),
			       .m_error(d_error),
			       .m_bytesel(d_bytesel),
			       .m_wr_en(d_wr_en),
			       .m_wr_val(d_wr_val),
			       .cacheable_addr(~dc_addr[29]));

oldland_debug		#(.icache_nr_lines(icache_nr_lines),
			  .dcache_nr_lines(dcache_nr_lines))
			debug(.clk(clk),
		              /* Controller to debug signals. */
		              .dbg_clk(dbg_clk),
		              .addr(dbg_addr),
		              .din(dbg_din),
		              .dout(dbg_dout),
		              .wr_en(dbg_wr_en),
		              .req(dbg_req),
		              .ack(dbg_ack),
			      .dbg_en(dbg_en),
			      /* External reset. */
			      .rst_req_in(rst_req),
		              /* Execution control. */
		              .run(cpu_run),
		              .stopped(cpu_stopped),
                              .bkpt_hit(dbg_bkpt_hit),
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
			      .dbg_icache_inval(dbg_icache_inval),
			      .dbg_icache_idx(dbg_icache_idx),
			      .dbg_dcache_flush(dbg_dcache_flush),
                              .dbg_dcache_inval(dbg_dcache_inval),
			      .dbg_dcache_idx(dbg_dcache_idx),
			      .dbg_icache_complete(dbg_icache_complete),
			      .dbg_dcache_complete(dbg_dcache_complete),
			      /* CPUID. */
			      .cpuid_sel(dbg_cpuid_sel),
			      .cpuid_val(cpuid_val));

oldland_pipeline	#(.icache_idx_bits(icache_idx_bits),
			  .dcache_idx_bits(dcache_idx_bits))
			pipeline(.clk(clk),
				 .irq_req(irq_req),
				 .running(running),
				 /* Instruction bus. */
				 .i_access(ic_access),
				 .i_addr(ic_addr),
				 .i_data(ic_data),
				 .i_ack(ic_ack),
				 .i_error(ic_error),
				 .i_idx(pipeline_icache_idx),
				 .i_inval(pipeline_icache_inval),
				 .i_cacheop_complete(i_cacheop_complete),
				 .i_cache_enabled(i_cache_enabled),
				 /* Data bus. */
				 .d_addr(dc_addr),
				 .d_bytesel(dc_bytesel),
				 .d_wr_en(dc_wr_en),
				 .d_wr_val(dc_wr_val),
				 .d_data(dc_data),
				 .d_access(dc_access),
				 .d_ack(dc_ack),
				 .d_error(dc_error),
				 .d_idx(pipeline_dcache_idx),
				 .d_inval(pipeline_dcache_inval),
				 .d_flush(pipeline_dcache_flush),
				 .d_cacheop_complete(d_cacheop_complete),
				 .d_cache_enabled(d_cache_enabled),
				 /* Debug signals. */
				 .run(cpu_run),
				 .stopped(cpu_stopped),
                                 .bkpt_hit(dbg_bkpt_hit),
				 .dbg_en(dbg_en),
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
				 /* CPUID. */
				 .cpuid_sel(cpu_cpuid_sel),
				 .cpuid_val(cpuid_val),
				 /* Reset. */
				 .dbg_rst(dbg_rst));

endmodule
