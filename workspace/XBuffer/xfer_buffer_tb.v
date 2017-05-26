module xfer_buffer_tb ();
	parameter io_act_nothing = 0;
	parameter io_get_rxbuf = 1;
	parameter io_act_writing = 2;
	parameter io_get_tx_buf = 3;
	parameter io_act_reading = 4;
	
	reg clock_host;
	reg reset, host_select, hwrite_enable, gs_select, gs_write_enable;
//	reg [31:0]	bus_address;
	wire [31:0] hostdata_inout;
	wire [7:0] 	gs_out;
	wire		gs_out_enable;
	reg [15:0]	tmp_cnt;

	// for inout wire,
	reg [31:0]	hostdata_out;
	reg			drive_w_enable;
	reg [31:0]	hostdata_in;
	
	reg [3:0]	io_mode; // 0: nothing, 1: rx_buf, 2: write, 3: tx_buf, 4: read
	
	assign hostdata_inout = (drive_w_enable) ? hostdata_out : 32'hz;

	initial 
	begin
		clock_host = 1'b1;
		reset = 1'b1;
		host_select = 1'b0;
		hwrite_enable = 1'b0;
		gs_select = 1'b0;
		gs_write_enable = 1'b0;
		tmp_cnt = 16'h0000;
		drive_w_enable = 1'b0;
		io_mode = io_get_rxbuf; 
	end
	
	always #5 clock_host = ~clock_host;
	 
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
		if (io_mode == io_act_writing) begin 
			host_select = 1;
			drive_w_enable = 1;	
			hostdata_out =  tmp_cnt; 
			hwrite_enable =  1;
		
			$display("TB @%d> tmp_cnt:%d", $time, tmp_cnt);
			
			tmp_cnt = tmp_cnt + 1; 
			if (tmp_cnt == 1024) begin 
				tmp_cnt = 0; 
				host_select = 0; 
				hwrite_enable = 0;
				io_mode = io_act_nothing;
			end 
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
		.gs_out_enable(gs_out_enable)
	);
	
		
endmodule
		