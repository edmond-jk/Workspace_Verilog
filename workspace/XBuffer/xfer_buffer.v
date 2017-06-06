module xfer_buffer(
	reset,
	clock_host,
	host_select,
	hwrite_enable,
//	buf_address, // TODO
	hostdata_inout,
	clock_fpga,
	xfer_buf_select,
	mwrite_enable,
	tbm_address,
	xfer_complete,
 	chip_select,
 	write_enable,
	maddress,
	mdata_inout,
	gs_select,
	gs_write_enable,
	gs_out,
	gs_out_enable
);
// parameter declarations related with data size
parameter 	HDATA_WIDTH = 32; 	// 4 Bytes
parameter	MDATA_WIDTH	= 256;
parameter 	ADDRESS_WIDTH = 32;	// 32 bits
parameter 	UNIT_BUF_BY_4B = 1024; // 1024 x 4 Byte ---> 4 KBytes
parameter 	UNIT_BUF_BY_32B = 128;
parameter 	TOTA_BUF_BY_4B = 4096; // 4096 x 4 Bytes --> 4 x 4 KBytes
parameter 	MAX_BUFQ_DEPTH = 4;

// parameters for the I/O modes of xfer_buffer
parameter 	io_host_nothing = 0;
parameter 	io_host_writing = 1;
parameter 	io_host_reading = 2;
parameter 	io_tbm_nothing = 0;
parameter	io_tbm_writing = 1;
parameter 	io_tbm_reading = 2;

// ports
input 							reset;
input							clock_host;
input							host_select;
input							hwrite_enable;
//input [ADDRESS_WIDTH - 1:0] 	buf_address;
inout [HDATA_WIDTH-1:0] 		hostdata_inout;
input							clock_fpga;
input							xfer_buf_select;
input 							mwrite_enable;
input [ADDRESS_WIDTH - 1:0]		tbm_address;
output							xfer_complete;
output							chip_select;
output							write_enable; 
output [31:0]					maddress; 
inout [MDATA_WIDTH-1:0]			mdata_inout;
 
input							gs_select;
input							gs_write_enable;
output [7:0]					gs_out;
output							gs_out_enable;
 
reg [HDATA_WIDTH-1:0]			rhostdata_inout;
reg [7:0]						gs_out;
reg								gs_out_enable;
reg								xfer_complete;
reg								chip_select;
reg								write_enable;
reg [31:0]						maddress;
reg[MDATA_WIDTH-1:0]			reg_mdata_inout;

reg								hdataflow_select; // 
reg								mdataflow_select; // 

 // Internal variables
reg [HDATA_WIDTH-1:0]		rx_buffer[0:TOTA_BUF_BY_4B-1]; // 4Bytes
reg [HDATA_WIDTH-1:0]		tx_buffer[0:TOTA_BUF_BY_4B-1];  
reg							rx_mutex, tx_mutex; // instead of mutex, 
reg [ADDRESS_WIDTH-1:0]		rx_address, tx_address; // tbm address
// 2^16 --> 64x1024

reg [3:0]					rx_head, rx_tail, tx_head, tx_tail; // 4KB buffer offset
reg [15:0]					hrx_idx, htx_idx, mx_idx; // idx is in total rx/tx buffers
reg [15:0]					offset_in_rxh, offset_in_rxt, offset_in_txh, offset_in_txt;
reg [1:0]					io_host_mode, io_tbm_mode;
reg [3:0]					mx_count;
reg [3:0]					tbm_read_wait_cycles, init_tx_skip;

assign hostdata_inout = hdataflow_select ? rhostdata_inout : 32'bz; //hdataflow_select is 0, host -> xfer_buffer
assign mdata_inout	= mdataflow_select ? reg_mdata_inout : 256'bz;

always @ (posedge clock_host)
begin 
	if (reset) begin
	 hdataflow_select <= 1'b0;
	 mdataflow_select <= 1'b0;
	 
	 rx_head <= 4'h0;
	 rx_tail <= 4'h0; 
	 tx_head <= 4'h0; 
	 tx_tail <= 4'h0;
	  
	 offset_in_rxh <= 16'h0000;
	 offset_in_rxt <= 16'h0000;
	 offset_in_txh <= 16'h0000;
	 offset_in_txt <= 16'h0000;
	 xfer_complete <= 1'b0;
	 chip_select <= 1'b0;
	 
	 io_host_mode = io_host_nothing;
	 io_tbm_mode = io_tbm_nothing;
	 tbm_read_wait_cycles = 0;
	 init_tx_skip = 0;
	 end
end

always @ (posedge clock_host or negedge clock_host)
begin
	if (gs_select) begin 
		if (gs_write_enable) begin
			gs_out_enable = 1'b1; 
			if (rx_head >= rx_tail) 
				gs_out = MAX_BUFQ_DEPTH - (rx_head - rx_tail) - 1;
			else 
				gs_out = rx_tail - rx_head - 1;	
		end else begin
			gs_out_enable = 1'b1;
			if (tx_head >= tx_tail)
				gs_out = tx_head - tx_tail;
			else
				gs_out = MAX_BUFQ_DEPTH - tx_tail + tx_head; 
		end
	end else begin
		gs_out_enable = 1'b0;
	end
end
		
always @ (posedge clock_host or negedge clock_host)
begin
	if ((io_host_mode == io_host_nothing) && host_select) begin
		if (hwrite_enable) begin
			io_host_mode = io_host_writing;
			hdataflow_select = 1'b0;
		end else begin
			io_host_mode = io_host_reading;
			hdataflow_select = 1'b1;
		end
	end
			
//	$display("XB @%d> clock:%b, host_select:%b, hwrite_enable:%b", $time, clock_host, host_select, hwrite_enable);

	case (io_host_mode)
		io_host_writing: 
		begin
			hrx_idx = rx_head * UNIT_BUF_BY_4B + offset_in_rxh; 
			rx_buffer[hrx_idx] = hostdata_inout; 
			offset_in_rxh = offset_in_rxh + 1;

//			$display("XB @%d> host_data:%d, rx_head:%d, offset_in_rxh:%d", $time, hostdata_inout, rx_head, offset_in_rxh);

			if (offset_in_rxh == UNIT_BUF_BY_4B) begin // 4096 Bytes / 4 Bytes --> 1024, 10 bits 
				offset_in_rxh = 16'h0000;	
				io_host_mode = io_host_nothing;
					
				rx_head = rx_head + 1; 
				if (rx_head == MAX_BUFQ_DEPTH) begin 
					rx_head = 4'h0;
				end
			end
		end
		io_host_reading:
		begin
			if (tx_head != tx_tail) begin // There are something in tx_buffer. 
				htx_idx = tx_tail * UNIT_BUF_BY_4B + offset_in_txt; 
				rhostdata_inout = tx_buffer[htx_idx];

				$display("xbuf@%d: offset:%d, hostdata_out:%h", $time, offset_in_txt, rhostdata_inout);		

				offset_in_txt = offset_in_txt + 1;	
			
				if (offset_in_txt == UNIT_BUF_BY_4B) begin // 32 bits x 8 = 256 bits
					offset_in_txt = 16'h0000;
					io_host_mode = io_host_nothing;
					
					tx_tail <= tx_tail + 1;
					if (tx_tail == MAX_BUFQ_DEPTH) begin
						tx_tail = 4'h0;
					end
				end
			end
		end
	endcase 
end
	
// bottom-half operations
always @ (posedge clock_fpga or negedge clock_fpga)
begin
	if ((io_tbm_mode == io_tbm_nothing) && xfer_buf_select) begin 
		if (mwrite_enable == 1)  begin 
			io_tbm_mode = io_tbm_writing;
			rx_address = tbm_address;
		end else begin
			io_tbm_mode = io_tbm_reading;
			tx_address = tbm_address;
		end
	end 
	// check these 
	chip_select = 0;
	xfer_complete = 1'b0;
	
	case (io_tbm_mode)
		io_tbm_writing:
		begin
			if (rx_head != rx_tail) begin
				chip_select = 1'b1;
				write_enable = 1'b1;
				mdataflow_select = 1;
			
				maddress = rx_address;
					
				for (mx_count = 0; mx_count < 8; mx_count = mx_count + 1) begin
					mx_idx = rx_tail * UNIT_BUF_BY_4B + offset_in_rxt;
					reg_mdata_inout[32 * mx_count +: 32] = rx_buffer[mx_idx]; // 4 Bytes 
					offset_in_rxt = offset_in_rxt + 1;
					rx_address = rx_address + 4;
				end
				
				if (offset_in_rxt == UNIT_BUF_BY_4B) begin
					offset_in_rxt = 16'h0;
					xfer_complete = 1'b1;
					
					$display ("io_tbm_writing complete 4KB data transfer");
					io_tbm_mode = io_tbm_nothing;
					
					rx_tail = rx_tail + 1; 
					if (rx_tail == MAX_BUFQ_DEPTH) begin 
						rx_tail <= 4'h0;
					end
				end
			end
		end
		
		io_tbm_reading:
		begin
			if ((tx_head - tx_tail + 1 != MAX_BUFQ_DEPTH) && (tx_tail - tx_head !== 1)) begin
				chip_select = 1;
				write_enable = 0;
				mdataflow_select = 0;
				
			
				if (tbm_read_wait_cycles <= 2)	begin
					tbm_read_wait_cycles = tbm_read_wait_cycles + 1; // TODO: to be modified 
					maddress = tx_address;
				end
					
				if (tbm_read_wait_cycles > 2) begin 
					
					if (init_tx_skip == 1) begin 
						offset_in_txh = 0;
						init_tx_skip = 4;
					end else if (init_tx_skip == 0) begin
						init_tx_skip = 1;
						mx_count = 8;
					end
						
					for (mx_count = 0; mx_count < 8; mx_count = mx_count + 1) begin
						
						mx_idx = tx_head * UNIT_BUF_BY_4B + offset_in_txh;
						tx_buffer[mx_idx] = mdata_inout[32* mx_count +: 32];
						offset_in_txh = offset_in_txh + 1;
						tx_address = tx_address + 4;
					end
						maddress = tx_address;
					
					if (offset_in_txh == UNIT_BUF_BY_4B) begin
						offset_in_txh = 16'h0;
						xfer_complete = 1'b1; 
						tbm_read_wait_cycles = 0;
						init_tx_skip = 0;
						io_tbm_mode = io_tbm_nothing;
				
						tx_head <= tx_head + 1;
						if (tx_head == MAX_BUFQ_DEPTH) begin
							tx_head <= 4'h0;
						end
					end
				end
			end
		end
	endcase
end	
		
endmodule
