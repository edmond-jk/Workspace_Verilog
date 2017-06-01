module ifq_tb();
	parameter io_act_initialize		= 0;
	parameter io_cmd_issue 			= 1;
	parameter io_get_rxbuf 			= 2;
	parameter io_act_writing 		= 3;
	parameter io_get_tx_buf 		= 4;
	parameter io_act_reading 		= 5;
	parameter io_act_mem_writing 	= 6;

	// common ports	
	reg clock_host;
	reg clock_fpga;
	reg reset;

	// ports for xfer_buffer
	reg 	host_select, hwrite_enable, gs_select, gs_write_enable;
	wire [31:0] hostdata_inout;
	wire [7:0] 	gs_out;
	wire		gs_out_enable;
	reg [15:0]	tmp_cnt;
	
	// ports for ifq
	reg				cmdq_select;
	reg [31:0]		cmd_in;
	reg				queryin_select;
	wire			queryout_select;
	wire [7:0]		querydata_inout;
	reg [7:0]		reg_querydata_out;	
	reg				querydata_flow;
	
	wire			sq_select;
	wire [255:0]	cmd_out;
	reg				status_update_enable;
	reg [7:0]		cmdq_index;	
	reg	[7:0]		cdb_row; // 4-byte row
	
	// connections between xfer_buffer and IFQueue
	wire xfer_buf_select;
	wire mwrite_enable;
	wire [31:0] tbm_address;
	wire	xfer_complete;

	// for in/out wire,
	reg [31:0]	hostdata_out;
	reg			drive_w_enable;
	
	reg [3:0]	io_mode; // 0: nothing, 1: rx_buf, 2: write, 3: tx_buf, 4: read

	// connections between xfer_buffer and tbm 
	wire [31:0] address_0;
	wire 		cs_0, we_0;
	wire [255:0] data_0;
	
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
		io_mode = io_cmd_issue; 
		cdb_row = 0;
	end
	
	always #5 clock_host = ~clock_host;
	always #7 clock_fpga = ~clock_fpga;
	 
	initial
	begin
		#10 reset = 0;
	end
	
	/*
	 * BSM_WRITE
	 * 1. CMD
	 * 2. GWS + fake read
	 * 3. Query command
	 * 4. Query command status
	 * 
	 * BSM_READ
	 * 1. CMD
	 * 2. Query command
	 * 3. Query command status
	 * 4. GRS + fake write 
	 */
	
	initial 
	forever begin 
		@ (posedge clock_host or negedge clock_host) 
		// 0. issue write command 
		if (io_mode == io_cmd_issue) begin
			cmdq_select = 1'b1;
			if (cdb_row == 0) begin
				cmd_in = {8'h00, 8'h00, 8'h00, 8'h40};	
				cdb_row = cdb_row + 1;
			end
			else if (cdb_row == 1) begin
				cmd_in = 32'h00000000;
				cdb_row = cdb_row + 1;
			end
			else if (cdb_row == 2) begin
				cmd_in = 32'h00000000;
				cdb_row = cdb_row + 1;
			end
			else if (cdb_row == 3) begin
				cmd_in = {8'h01, 8'h00, 16'h0008};
				cdb_row = cdb_row + 1;
			end
			else if ((cdb_row == 4) || (cdb_row == 5) || (cdb_row == 6) || (cdb_row == 7)) begin
				cmd_in = 32'h00000000;
				cdb_row = cdb_row + 1;
			end
			else if (cdb_row == 8) begin
				io_mode = io_get_rxbuf;	
				cdb_row = 0;
				cmdq_select = 1'b0;
			end
		end
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
			
			if (xfer_complete == 1)
				$display ("@%d: data transfer (-> tbm) is done", $time);
		end
	end

	xfer_buffer U0 (
		.reset(reset), 
		.clock_host(clock_host), 
		.host_select(host_select),
		.hwrite_enable(hwrite_enable),
		.hostdata_inout(hostdata_inout),
		.gs_select(gs_select),
		.gs_write_enable(gs_write_enable),
		.gs_out(gs_out),
		.gs_out_enable(gs_out_enable),
		.clock_fpga(clock_fpga),
		.xfer_buf_select(xfer_buf_select),
		.mwrite_enable(mwrite_enable),
		.tbm_address(tbm_address),
		.xfer_complete(xfer_complete),
		.chip_select(cs_0),
		.write_enable(we_0),
		.maddress(address_0),
		.mdata_inout(data_0)	
	);
	
	tbm U1 (
		.clock(clock_fpga),
		.address_0(address_0),
		.data_0(data_0),
		.cs_0(cs_0),
		.we_0(we_0)
	);
	
	ifq U2 (
		.clock_host(clock_host),
		.clock_fpga(clock_fpga),
		.reset(reset),
		.cmdq_select(cmdq_select),
		.cmd_in(cmd_in),
		.queryin_select(queryin_select),
		.queryout_select(queryout_select),
		.querydata_inout(querydata_inout),
		.sq_select(sq_select),
		.cmd_out(cmd_out),
		.status_update_enable(status_update_enable),
		.cmdq_index(cmdq_index),
		.xfer_buf_select(xfer_buf_select),
		.mwrite_enable(mwrite_enable),
		.tbm_address(tbm_address),
		.xfer_complete(xfer_complete)
	);
	
		
endmodule