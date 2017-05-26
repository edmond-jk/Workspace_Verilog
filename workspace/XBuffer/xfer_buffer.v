module xfer_buffer(
	reset,
	clock_host,
	host_select,
	hwrite_enable,
//	buf_address,
	hostdata_inout,
//	clock_fpga,
//	xfer_buf_select,
//	mwrite_enable,
//	tbm_address,
//	xfer_complete,
// chip_select,
// write_enable,
// maddress,
// mdata_inout,
	gs_select,
	gs_write_enable,
	gs_out,
	gs_out_enable
);
// parameter declarations related with data size
parameter HDATA_WIDTH = 32; 	// 4 Bytes
parameter ADDRESS_WIDTH = 32;	// 32 bits
parameter UNIT_BUF_BY_4B = 1024; // 1024 x 4 Byte ---> 4 KBytes
parameter TOTA_BUF_BY_4B = 4096; // 4096 x 4 Bytes --> 4 x 4 KBytes
parameter MAX_BUFQ_DEPTH = 4;

// parameters for the I/O modes of xfer_buffer

// ports
input 							reset;
input							clock_host;
input							host_select;
input							hwrite_enable;
//input [ADDRESS_WIDTH - 1:0] 	buf_address;
inout [HDATA_WIDTH-1:0] 		hostdata_inout;
//input							clock_fpga;
//input							xfer_buf_select;
//input 							mwrite_enable;
//input [ADDRESS_WIDTH - 1:0]		tbm_address;
//output							xfer_complete;
//output			chip_select;
//output			write_enable; 
//output [31:0]	maddress; 
//inout [255:0]	mdata_inout;
 
input							gs_select;
input							gs_write_enable;
output [7:0]					gs_out;
output							gs_out_enable;
 
reg [HDATA_WIDTH-1:0]			rhostdata_inout;
reg [7:0]						gs_out;
reg								gs_out_enable;

reg								hdataflow_select; // 

 // Internal variables
reg [HDATA_WIDTH-1:0]		rx_buffer[0:TOTA_BUF_BY_4B-1];
reg [HDATA_WIDTH-1:0]		tx_buffer[0:TOTA_BUF_BY_4B-1];  
reg [3:0]					rx_head, rx_tail, tx_head, tx_tail; // 4KB buffer offset
reg [3:0]					rx_anum, tx_anum; // the number of available rx/tx buffers
reg							rx_mutex, tx_mutex; // instead of mutex, 
//reg [7:0]					mtoBufOffset, mfromBufOffset; // MDATA
reg [ADDRESS_WIDTH-1:0]		rx_address, tx_address; // tbm address
reg [1:0]					mxferprocessing; // write data to tbm : 1, read data from tbm : 2
// 2^16 --> 64x1024
reg [15:0]					rx_idx, tx_idx, rx_head_idx, rx_tail_idx, tx_head_idx, tx_tail_idx;

assign hostdata_inout = hdataflow_select ? rhostdata_inout : 32'hz; //hdataflow_select is 0, host -> xfer_buffer

always @ (posedge clock_host)
begin 
	if (reset) begin
	 hdataflow_select <= 0;
	 rx_head <= 4'h0;
	 rx_tail <= 4'h0; 
	 tx_head <= 4'h0; 
	 tx_tail <= 4'h0;
	  
	 rx_anum <= MAX_BUFQ_DEPTH;
	 tx_anum <= MAX_BUFQ_DEPTH;
	 rx_mutex <= 1'b0;
	 tx_mutex <= 1'b0; 
	 
	 rx_head_idx <= 16'h0000;
	 rx_tail_idx <= 16'h0000;
	 tx_head_idx <= 16'h0000;
	 tx_tail_idx <= 16'h0000;
	 
	 mxferprocessing <= 2'b00;
	 end
end

always @ (posedge clock_host or negedge clock_host)
begin
	$display("XB @%d> clock:%b, host_select:%b, hwrite_enable:%b", $time, clock_host, host_select, hwrite_enable);
	
	if (host_select) begin
		if (hwrite_enable) begin
		
			rx_idx = rx_head * UNIT_BUF_BY_4B + rx_head_idx;
			rx_buffer[rx_idx] = hostdata_inout;
			rx_head_idx = rx_head_idx + 1;

			$display("XB @%d> host_data:%h, rx_head:%d, rx_idx:%d", $time, hostdata_inout, rx_head, rx_idx);

			if (rx_head_idx == UNIT_BUF_BY_4B) begin // 4096 Bytes / 4 Bytes --> 1024, 10 bits 
				rx_head_idx = 16'h0000;	
				
				if (rx_mutex) begin // TODO: need to modify
				 	wait (rx_mutex == 1'b0);
				 	rx_mutex <= 1'b1;
				 	rx_anum <= rx_anum - 1;
				 	rx_mutex <= 1'b0;
				end
				rx_head = rx_head + 1; 
				if (rx_head == MAX_BUFQ_DEPTH) begin 
					rx_head <= 4'h0;
				end
			end
		end else begin 
			if (tx_anum != MAX_BUFQ_DEPTH) begin // There are something in tx_buffer.
				tx_idx = tx_tail * UNIT_BUF_BY_4B + tx_tail_idx;
				rhostdata_inout = tx_buffer[tx_idx];
				tx_tail_idx = tx_tail_idx + 1;			
				if (tx_tail_idx == UNIT_BUF_BY_4B) begin // 32 bits x 8 = 256 bits
					tx_tail_idx <= 16'h0000;
					if(tx_mutex) begin // TODO: need to modify
						wait (tx_mutex == 1'b0); 
						tx_mutex <= 1'b1; 
						tx_anum <= tx_anum + 1; 
						tx_mutex <= 1'b0; 
							
						tx_tail <= tx_tail + 1;
						if (tx_tail == MAX_BUFQ_DEPTH) begin
							tx_tail <= 4'h0;
						end
					end
				end
			end
		end
	end
end

// bottom-half processing will be implemented later.	
		
always @ (posedge clock_host or negedge clock_host) 
begin 
	if (gs_select) begin
		if (gs_write_enable) begin
			gs_out_enable = 1'b1;
			gs_out = rx_anum;
		end else begin
			gs_out_enable = 1'b1;
			gs_out = tx_anum;
		end
	end else begin 
		gs_out_enable = 1'b0;
	end
end

endmodule
