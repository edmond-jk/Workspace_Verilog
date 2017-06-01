`include "hd_parameter.vh"
/*
 * If read command comes before writing the data with the same address, . 
 * Currently this condition have to be solved in the device driver. 
 */
module ifq(
	reset,
	clock_host,
	clock_fpga,
	cmdq_select,
	cmd_in,
	xfer_buf_select,
	mwrite_enable,
	tbm_address,
	xfer_complete,
	queryin_select,
	queryout_select,
	querydata_inout,
	sq_select,
	cmd_out,
	status_update_enable,
	cmdq_index
);

// ports
input				reset;
input 				clock_host;
input				clock_fpga;
input				cmdq_select;
input [31:0]		cmd_in;
output				xfer_buf_select;
output				mwrite_enable;
output [31:0]		tbm_address;			
input				xfer_complete;
input 				queryin_select;
output				queryout_select;
inout [7:0]			querydata_inout;			
output				sq_select;
output [255:0]		cmd_out;
input				status_update_enable;
input [7:0]			cmdq_index;

// data types for ports
reg					xfer_buf_select;
reg					mwrite_enable;
reg [31:0]			tbm_address;
reg					queryout_select;
wire [7:0]			querydata_inout;
reg					sq_select;
reg [255:0]			cmd_out;
reg	[7:0]			reg_querydata_inout;
reg					querydata_flow;

reg [7:0] 			ifcmdQ[`MAX_CMDQ_DEPTH-1:0][31:0]; //1 byte x 32 bytes x 32
reg [7:0]			head, tail, current;
reg [7:0]			in_offset, out_offset;
reg					ev_xfer_complete;	
reg	[7:0]			offset_by_byte, valid_byte, count_rx, count_tx;
reg [15:0]			req_size, tmp_address;
reg [1:0]			current_xtbm_mode; // io mode between xfer_buffer and tbm	
reg [1:0]			before_xtbm_mode;
reg [7:0]			count_cmd_in;

assign querydata_inout = (querydata_flow) ? reg_querydata_inout : 8'hz; 

// reset all parameters
always @ (posedge clock_host)
begin
	if (reset) begin
		head = 8'h00;
		tail = 8'h00;
		current = 8'h00;
		in_offset = 8'h00;
		out_offset = 8'h00;
		ev_xfer_complete = 1'b0;
		querydata_flow = 1'b0;
		count_rx = 8'h00;
		count_tx = 8'h00;
		current_xtbm_mode = `XTBM_NOTHING;
		before_xtbm_mode = `XTBM_READING;
	end
end

// receiving a new command
always @ (posedge clock_host or negedge clock_host)
begin
	if (cmdq_select) begin
		for (count_cmd_in = 0; count_cmd_in < 4; count_cmd_in = count_cmd_in + 1) begin
		  	ifcmdQ[head][in_offset] = cmd_in[count_cmd_in*8 +: 8];
			in_offset = in_offset + 1;
		end
		
		if (in_offset == 32) begin
			in_offset = 0;
			head = head + 1;
			if (head == `MAX_CMDQ_DEPTH) 
				head = 0;
		end
	end
end

// manage I/O mode between xfer_buffer and tbm
always @ (posedge clock_host or negedge clock_host or posedge clock_fpga or negedge clock_fpga)
begin
	if (current_xtbm_mode == `XTBM_NOTHING) begin
		if (before_xtbm_mode == `XTBM_READING)  begin
			current_xtbm_mode = `XTBM_WRITING;
			before_xtbm_mode = `XTBM_WRITING;
		end else begin
			current_xtbm_mode = `XTBM_READING;
			before_xtbm_mode = `XTBM_READING;
		end
	end
end
		
// processing a new command
always @ (posedge clock_fpga or negedge clock_fpga)
begin
	if (current != head) begin
		req_size =  {ifcmdQ[current][`REQ_SIZE + 1], ifcmdQ[current][`REQ_SIZE]}; // TO check 
		req_size = req_size >> 3; // 512B sectors --> # of 4KBs
		$display ("@%d: request size (4KB) is %d", $time, req_size);
		
		if (ifcmdQ[current][`CMD_TYPE] == `BSM_WRITE) begin
			
			if (current_xtbm_mode == `XTBM_READING || current_xtbm_mode == `XTBM_NOTHING)	
				wait(current_xtbm_mode == `XTBM_WRITING);
			
			while (count_rx < req_size) 
			begin
				valid_byte = ifcmdQ[current][`VALID_BITS];		
				if ((valid_byte >> count_rx) & 8'h01) begin
					xfer_buf_select = 1;
					mwrite_enable = 1;
					 
					tbm_address = ifcmdQ[current][`INTERNAL_BUF_BASE + count_rx * 2];
					wait (ev_xfer_complete == 1'b1);
					
					xfer_buf_select = 1'b0;
					mwrite_enable = 1'b0;
				end
				count_rx = count_rx + 1;
			end
			/*
			 * TODO: This command has to be copied to the storage queue. 
			 */
			
			current_xtbm_mode = `XTBM_NOTHING;	
			count_rx = 0;	
			ifcmdQ[current][`OP_STATUS] = `ST_DONEB;
			
		end else if (ifcmdQ[current][`CMD_TYPE] == `BSM_READ) begin
			if (current_xtbm_mode == `XTBM_WRITING) begin
				current_xtbm_mode = `XTBM_NOTHING;
			end
		
			while (count_rx < req_size)  // TODO 
			begin
				valid_byte = ifcmdQ[current][`VALID_BITS];	
				if ((valid_byte >> count_rx) & 8'h01) begin
					/*
					 * In this case, the designated 4KB data is in the tbm buffer. 
					 */
				end else begin
					ifcmdQ[current][`OP_STATUS] = `ST_WAITS;
					// TODO: this command descriptor should be copied to the storage queue
				end
				count_rx = count_rx + 1;
			end // while-loop
			
			count_rx = 0;
			
			if (ifcmdQ[current][`OP_STATUS] != `ST_WAITS)
				ifcmdQ[current][`OP_STATUS]	 = `ST_DONEB;
		end
		current = current + 1;
		if (current == `MAX_CMDQ_DEPTH)
			current = 8'h00; 
	end 
end


// update the status of the command queue
always @ (posedge clock_fpga or negedge clock_fpga)				
begin
	if (status_update_enable) 
		ifcmdQ[cmdq_index][`OP_STATUS] = `ST_DONED; 
end	

// closing the command		
always @ (posedge clock_host or negedge clock_host)
begin
	querydata_flow = 1'b0;
	queryout_select = 1'b0;
	
	if (queryin_select) begin
		if (ifcmdQ[tail][`TAG] == querydata_inout) begin
			if (ifcmdQ[tail][`CMD_TYPE] == `BSM_WRITE) begin
				if ((ifcmdQ[tail][`OP_STATUS] == `ST_DONEB) || (ifcmdQ[tail][`OP_STATUS] == `ST_DONED)) begin
					reg_querydata_inout[3:2] = `QS_DONE;
					querydata_flow = 1'b1;
					queryout_select = 1'b1;
					
					ifcmdQ[tail][`OP_STATUS] = `ST_FREE;
					tail = tail + 1;
					if (tail == `MAX_CMDQ_DEPTH)
						tail = 0;
				end else begin
					reg_querydata_inout[3:2] = `QS_INPROCESS;
					queryout_select = 1'b1;
					querydata_flow = 1'b1;
				end
			end	else if (ifcmdQ[tail][`CMD_TYPE] == `BSM_READ) begin
				if ((ifcmdQ[tail][`OP_STATUS] == `ST_DONEB) || (ifcmdQ[tail][`OP_STATUS] == `ST_DONED)) begin
					reg_querydata_inout [3:2] = `QS_DONE;
					queryout_select = 1'b1;
					querydata_flow = 1'b1;
				
					if ((current_xtbm_mode == `XTBM_WRITING) || (current_xtbm_mode == `XTBM_NOTHING)) 
						wait (current_xtbm_mode == `XTBM_READING);
					
					while (count_tx < 8) begin
						valid_byte = ifcmdQ[tail][`VALID_BITS];
						if ((valid_byte >> count_tx) & 8'h01) begin
							xfer_buf_select = 1;
							mwrite_enable = 0;
						 	tbm_address = ifcmdQ[tail][`INTERNAL_BUF_BASE + count_tx * 2]; 
						 	
						 	wait (ev_xfer_complete == 1'b1);
							xfer_buf_select = 1'b0;
						end
						count_tx = count_tx + 1;
					end // while 
				
					current_xtbm_mode = `XTBM_NOTHING;
						
					ifcmdQ[tail][`OP_STATUS] = `ST_FREE;
					tail = tail + 1;
					if (tail == `MAX_CMDQ_DEPTH)
						tail = 0;
				end else begin
					reg_querydata_inout [3:2] = `QS_INPROCESS;
					queryout_select = 1'b1;
					querydata_flow = 1'b1;
				end
			end 
		end	
	end
end
endmodule
