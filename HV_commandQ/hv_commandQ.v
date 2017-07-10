module hv_commandQ 
  #(parameter CMD_IO_WIDTH		= 64)
  (
	input wire							clk,
	input wire							reset,
	
	input wire							cmd_ie,			// command input enable 
	input wire 	[CMD_IO_WIDTH-1: 0]		cmd_in, 		// when inserting a new command to the command Q,
	
	input wire							cmd_request, 	// when command processor request a new command,
	output wire							cmd_oe,			// command output enable
	output wire [CMD_IO_WIDTH-1: 0]		cmd_out,		// when fetching a new command for the command Q,

	output wire							cq_cin_ready,  	// the status of commandQ: Full (0) or Avail (1)
	output wire							cq_cout_ready,	// Empty (0) or Avail (1)
	
	input wire [7:0]					op_index,			// to identify a specific command 
	input wire [7:0]					cmd_op_status,  	// to identify the operational status of a command  
 	
 	// If TBM address is allocated and used in the command,
 	input wire							tbm_ie,
 	input wire [7:0]					tbm_index,	
 	input wire [31:0]					tbm_address,	
 	// Query command request.
 	// Supposed that query command is handled in a different place from the command FIFO queue
 	input wire							query_ie,	
 	input wire [7:0]					query_tag,
 	output wire							query_oe,
 	output wire[CMD_IO_WIDTH-1:0]		query_out 
  );
  
  
  /* 
   * the status of a specific command in the command queue
   */
  parameter CMD_ST_FREE			= 0;	// this CDB (Command Descriptor Block) slot is available for any new command
  parameter CMD_ST_INSERTED		= 1; 	// this CDB is just inserted/queued into the command queue
  parameter CMD_ST_CKS_ERROR	= 2;	// this CDB has some errors because its calculated checksum is not equal to the included checksum.
  parameter CMD_ST_READY		= 3; 	// this CDB is waiting for the call from the command processor. 	
  parameter CMD_ST_Q2D			= 4;	// this command is fetched by the command processor
  parameter CMD_ST_X2M			= 5; 	// the data designated by this CDB was transferred to TBM
  parameter CMD_ST_Q2S			= 6; 	// this command was issued to the back-end (flash) storage  
  
  // in the case of write, the requested data is written to the back-end storage, 
  // in the case of read, the requested data  is read from the back-end storage to TBM. 
  parameter CMD_ST_DONE			= 6;	
  parameter CMD_ST_QUERIED		= 7;
  parameter CMD_ST_Q2D_ERROR	= 8;	// this command w/ error is queried and have to be recovered afterwards
  parameter CMD_ST_QUERIED_ERROR = 9;	// in the case of read command  
  /*
   *  DATA WIDTH DEFINITION
   */
  parameter CMD_MAX_QDEPTH_BIT	= 5; 						// Max. queue depth is 32.
  parameter CDB_SIZE_BIT		= 8; 						// 32 bytes per FPGA 
  parameter CDB_SIZE			= 2**CDB_SIZE_BIT;			// 256 bits
  parameter CDB_WORD_SIZE_BIT	= 5;						// 4 byte (32 bits) per single word 
  parameter CDB_WORD_SIZE		= 2**CDB_WORD_SIZE_BIT; 	// 32 bits 
  parameter CQ_MAX_DEPTH		= 2**CMD_MAX_QDEPTH_BIT;	// the maximum depth of CQ
  parameter CHECKSUM_POSITION	= 128;
   
  parameter INIT_CKS_STATE		= 0;
  parameter CKS_CAL_STATE		= 1;
  parameter CKS_JUDGE_STATE		= 2;
  parameter CKS_DONE_STATE		= 3;
   
  parameter INIT_OXFER_STATE	= 0;
  parameter OXFER_PROC_STATE	= 1;
  parameter OXFER_WAIT_STATE 	= 2;
  parameter OXFER_SKIP_STATE	= 3; // skip error
   
  parameter INIT_QUERY_STATE	= 0;
  parameter QUERY_PROC_STATE	= 1;
  parameter QUERY_DONE_STATE	= 2;
  parameter QUERY_OXFER_STATE	= 3;
   
  parameter QUERY_BACK_LIMIT	= 12;
  
  // head position is used to designate  a position for a new command.
  // tail position is used to designate the oldest command remaining in the command queue.
  // current position is used to process something according to the external order or request
  reg [CMD_MAX_QDEPTH_BIT-1 : 0]		head, tail, current, cks_pos, query_pos; 
  reg [CDB_SIZE-1 : 0]					CQ [0: CQ_MAX_DEPTH -1];
  reg									tmp_cmd_oe, tmp_query_oe;
  reg [CMD_IO_WIDTH-1: 0]				tmp_cmd_out, tmp_query_out;
  reg [7:0]								internal_tag;
   
  reg [3:0]								checksum_state, oxfer_state, query_state;
  reg [7:0]								cin_pos, cout_pos, qout_pos;
  reg [7:0]								q_error_pos, q_done_pos;
  reg [7:0]								q_error_cnt, q_done_cnt;
  reg [31:0]							cks_result;
  
  reg [CDB_SIZE-1: 0]					query_response;
  reg [7:0]								tmp_query_tag;	
  reg									tmp_cout_ready;
  
  assign cmd_oe 		= tmp_cmd_oe;
  assign cmd_out		= tmp_cmd_out;  
  assign cq_cout_ready	= (current == head) ? 0 : (tmp_cout_ready ? 1 : 0); 	// if (current == head), empty
  assign cq_cin_ready 	= (tail == head + 1 ) ? 0 : 1; 	// if (tail == head + 1), full
  assign query_oe		= tmp_query_oe;
  assign query_out		= tmp_query_out;
  
   
  // Reset internal variables 
  always @ (posedge clk or negedge reset)
  	begin
  		if (reset)
  			begin
  				head 			<= 0; 
  				tail 			<= 0;
  				current 		<= 0;
  				cks_pos 		<= 0;
  				internal_tag	<= 0;
  				
  				tmp_cmd_oe 		<= 0;	
  				tmp_query_oe 	<= 0;
  				cin_pos 		<= 0;
  				cout_pos 		<= 0;
  				qout_pos		<= 0;
  				query_pos 		<= 0;
  				q_error_pos		<= 0;
  				q_done_pos		<= 0;
  				q_error_cnt		<= 0;
  				q_done_cnt		<= 0;
  				
  				checksum_state 	<= INIT_CKS_STATE;
  				oxfer_state		<= INIT_OXFER_STATE;
  				query_state		<= INIT_QUERY_STATE;
  				
  				tmp_cout_ready 	<= 1;
  			end
  	end
  
  // inserting a new command to the command queue
  always @ (posedge clk)
  	begin
  		if (cmd_ie)
  			begin
				
  				CQ[head] [cin_pos +: CMD_IO_WIDTH] <= cmd_in;
  				
  				$display("cin_pos: %d: %X", cin_pos, cmd_in);
  				
  				// TODO checksum calculation part, MUST BE MODIFIED according to algorithm  	
  				if (cin_pos == 0)
  					begin 
  						cks_result <= cmd_in[31:0] ^ cmd_in[63:32];
  					end
  				else
  					begin
  						cks_result <= cks_result ^ cmd_in[31:0] ^ cmd_in[63:32];
  					end
  				
  				if (cin_pos + CMD_IO_WIDTH == CDB_SIZE) 
  					begin
  						cin_pos				<= 0;
  						cks_pos				<= head;
		  				head 				<= head + 1; 
		  				
		  				if (current  == head) 
		  					begin
								tmp_cout_ready <= 0;
							end
		  				
		  				checksum_state		<= CKS_JUDGE_STATE;
		  				
		  				// This variable will not be necessary if the head bit size is equal to 
		  				// the internal_tag bit size. The goal of internal_tag is tracking 
		  				// tag sequence number. 	
		  				internal_tag 		<= internal_tag + 1; 
  					end
  				else
  					begin
		  				cin_pos	<= cin_pos + CMD_IO_WIDTH;	
  					end
  			end
  	end
 
  // when fetching a queued command to process.  
  always @ (posedge clk)
  	begin
  		case (oxfer_state)
  			INIT_OXFER_STATE:
  			begin
  				// Supposed that cmd_request is enable for single clock after confirming 
  				// there are available commands in the command queue.
  				
  				tmp_cmd_oe <= 0;
  				
  				if (cmd_request && (current != head))  
  					begin
  						if (CQ[current][31:24] == CMD_ST_READY)
  							begin
  								oxfer_state <= OXFER_PROC_STATE;
  							end
  						else if (CQ[current][31:24] == CMD_ST_INSERTED)
  							begin
  								oxfer_state <= OXFER_WAIT_STATE;
  							end
  						else if (CQ[current][31:24] == CMD_ST_CKS_ERROR) 
  							// in the case of write command, processor must solve this command by using GWS
  							begin 
  								oxfer_state <= OXFER_PROC_STATE;  	
  							end
  					end
  			end
  			
  			OXFER_PROC_STATE:
  			begin
  				tmp_cmd_oe 	<= 1;
  				tmp_cmd_out <= CQ[current][cout_pos +: CMD_IO_WIDTH];
  				
  				if (cout_pos + CMD_IO_WIDTH == CDB_SIZE)
  					begin
  						cout_pos <= 0;
  						if (CQ[current][31:24] == CMD_ST_CKS_ERROR)
  							begin
  								// write command
		  						CQ[current][31:24] <= CMD_ST_Q2D_ERROR;
  							end
  						else
  							begin
  								CQ[current][31:24] <= CMD_ST_Q2D;
  							end
  							
  						current <= current + 1;
  						
  						oxfer_state <= INIT_OXFER_STATE;
  					end
  				else
  					begin
  						cout_pos <= cout_pos + CMD_IO_WIDTH;
  					end
  			end
  			
  			OXFER_WAIT_STATE:
  			begin
  				if (CQ[current][31:24] == CMD_ST_INSERTED)
  					begin
  						// wait
  					end
  				else	// CMD_ST_READY or CMD_ST_CKS_ERROR   					
  					begin
  						oxfer_state <= OXFER_PROC_STATE;
  					end 
  			end
  		endcase
  	end
  
  // calculate the checksum of the command and judge whether some errors happen or not.  
  always @ (posedge clk) 
  	begin
  		case (checksum_state)
  			INIT_CKS_STATE:
  			begin
  			end
			
			CKS_JUDGE_STATE:
			begin
				if (cks_result == 0)
					begin
						CQ[cks_pos][31:24] <= CMD_ST_READY;
					end
				else
					begin
						CQ[cks_pos][31:24] <= CMD_ST_CKS_ERROR;		
					end
				
				tmp_cout_ready 		<= 1;	
				CQ[cks_pos][23:16] 	<= cks_pos;	
				
				checksum_state 		<= INIT_CKS_STATE;
			end
			
  		endcase
  	end

  always @ (posedge clk)
  	begin
  		// when cmd_op_status coming from external, cmd_op_status will not be 0.
  		if (cmd_op_status) 
  			begin
  				CQ[op_index][31:24] <= cmd_op_status;
  			end
  	end
  	
  always @ (posedge clk)
  	begin
  		if (tbm_ie)
  			begin
  				CQ[tbm_index] [191:160] <= tbm_address;
  			end
  	end
  	
  /*
   * Query Response
   * The existing query status (07/06/2017)
   * [7:4] 	Estimated completion time 
   * [3:2] 	00b: no command, 01b: command in FIFO, 10b: command is being processed by FPGA, 11b: command done
   * [1]	eMMC CRC: This field indicates CRC error from eMMC,
   * [0] 	Command sync. counter
   */
  always @ (posedge clk)
  	begin
  		case (query_state)
  			INIT_QUERY_STATE:
  			begin
  				tmp_query_oe	<= 0;
  		
  				if (query_ie)
  					begin
  						query_response [15:8] <= query_tag;
  						query_state <= QUERY_PROC_STATE;
  					end
  			end
  			
  			QUERY_PROC_STATE:
  			begin
  				if (CQ[query_pos][31:24] == CMD_ST_CKS_ERROR)
  					begin
  						query_response [(q_error_pos + 160) +: 8] <= CQ[query_pos][15:08];
  						q_error_pos <= q_error_pos + 8;
  						q_error_cnt <= q_error_cnt + 1;
  						
  						CQ[query_pos][31:24] <= CMD_ST_Q2D_ERROR;
  						
  						if ((q_error_cnt + 1) == QUERY_BACK_LIMIT)
  							begin
  								query_state <= QUERY_DONE_STATE;
  							end
  					end
  				else if (CQ[query_pos][31:24] == CMD_ST_DONE)
  					begin
  						query_response [(q_done_pos + 32) +: 8] <= CQ[query_pos][15:08];
  						q_done_pos <= q_done_pos + 8;
  						q_done_cnt <= q_done_cnt + 1;
  						
  						CQ[query_pos] <= CMD_ST_QUERIED;
  						
  						if ((q_done_cnt + 1) == QUERY_BACK_LIMIT)
  							begin
  							end
  					end
  					
  					if ((query_pos + 1)	== head)
  						begin
  							query_state <= QUERY_DONE_STATE;
  						end 
  					
  					query_pos <= query_pos + 1;
  			end
  			
  			QUERY_DONE_STATE:
  			begin
  				query_pos 	<= 0;
  				q_done_pos 	<= 0;
  				q_error_pos <= 0;
  				q_done_cnt	<= 0;
  				q_error_cnt	<= 0;
  				
  				query_state	<= QUERY_OXFER_STATE;
  			end
  			
  			QUERY_OXFER_STATE:
  			begin
  				tmp_query_oe 	<= 1;
  				tmp_query_out	<= query_response [qout_pos +: CMD_IO_WIDTH];
  				
  				if (qout_pos + CMD_IO_WIDTH == CDB_SIZE)
  					begin
  						qout_pos <= 0;
  						query_state <= INIT_QUERY_STATE;
  					end
  				else
  					begin
  						qout_pos <= qout_pos + CMD_IO_WIDTH;
  					end
  			end
  		endcase	
  		
  	end
endmodule