module xfer_buffer_tb ();
	parameter io_act_nothing = 0;
	parameter io_get_rxbuf = 1;
	parameter io_act_writing = 2;
	parameter io_get_tx_buf = 3;
	parameter io_act_reading = 4;
	parameter io_act_mem_writing = 5;
	
	reg clock_host;
	reg reset, host_select, hwrite_enable, gs_select, gs_write_enable;
//	reg [31:0]	bus_address;
	wire [31:0] hostdata_inout;
	wire [7:0] 	gs_out;
	wire		gs_out_enable;
	reg [15:0]	tmp_cnt;
	
	reg clock_fpga;
	reg xfer_buf_select;
	reg mwrite_enable;
	reg [31:0] tbm_address;
	wire	xfer_complete;

	// for inout wire,
	reg [31:0]	hostdata_out;
	reg			drive_w_enable;
	reg [31:0]	hostdata_in;
	
	reg [3:0]	io_mode; // 0: nothing, 1: rx_buf, 2: write, 3: tx_buf, 4: read
	
	assign hostdata_inout = (drive_w_enable) ? hostdata_out : 32'hz;

	initial 
	begin
		clock_host = 1'b1;
		clock_fpga = 1'b1;
		reset = 1'b1;
		host_select = 1'b0;
		hwrite_enable = 1'b0;
		gs_select = 1'b0;
		gs_write_enable = 1'b0;
		tmp_cnt = 16'h0000;
		drive_w_enable = 1'b0;
		io_mode = io_get_rxbuf; 
		xfer_buf_select = 1'b0;
		mwrite_enable = 1'b0;
	end
	
	always #5 clock_host = ~clock_host;
	always #7 clock_fpga = ~clock_fpga;
	 
	initial
	begin
		#10 reset = 0;
	end
	
	initial 
	forever begin 
		@ (posedge clock_host or negedge clock_host) 
		// 1. confirm what general write setup is  	
		if (io_mode == io_get_rxbuf) begin
			gs_select = 1'b1;
			gs_write_enable = 1'b1;
		end
		// 2. before transferring data to HD, you have to confirm if there are available buffers. 
		if (gs_out_enable) begin
			$display("TB @%d> gs_out:%h", $time, gs_out);
			gs_select = 1'b0;
			gs_write_enable = 1'b0;
			if (gs_out != 0) begin
				io_mode = io_act_writing;	
			end
		end
			
		// 3. data transfer 	
		if (tmp_cnt == 1024) begin 
			tmp_cnt = 0; 
			host_select = 0; 
			hwrite_enable = 0;
			io_mode = io_act_mem_writing;
		end 
		
		if (io_mode == io_act_writing) begin 
			host_select = 1;
			drive_w_enable = 1;	
			hostdata_out =  tmp_cnt; 
			hwrite_enable =  1;
		
			$display("TB @%d> tmp_cnt:%d", $time, tmp_cnt);
			
			tmp_cnt = tmp_cnt + 1; 
		end
		
		// 4. rx_buf --> tbm
		if (io_mode == io_act_mem_writing) begin
			$display("@%d:io_act_mem_writing",$time);
			xfer_buf_select = 1;
			mwrite_enable = 1;
			tbm_address = 0;
			if (xfer_complete == 1)
				$display ("@%d: data transfer (-> tbm) is done", $time);
		end
	end

	xfer_buffer U0 (
		.reset(reset), 
		.clock_host(clock_host), 
		.host_select(host_select),
		.hwrite_enable(hwrite_enable),
	//	.buf_address(buf_address),
		.hostdata_inout(hostdata_inout),
		.gs_select(gs_select),
		.gs_write_enable(gs_write_enable),
		.gs_out(gs_out),
		.gs_out_enable(gs_out_enable),
		.clock_fpga(clock_fpga),
		.xfer_buf_select(xfer_buf_select),
		.mwrite_enable(mwrite_enable),
		.tbm_address(tbm_address),
		.xfer_complete(xfer_complete)
	);
	
		
endmodule
		