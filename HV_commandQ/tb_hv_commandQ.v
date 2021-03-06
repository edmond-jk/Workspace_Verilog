module tb_hv_commandQ ();
  localparam CLK_HALF_PERIOD = 1; 
  localparam CLK_PERIOD = 2 * CLK_HALF_PERIOD; 
  localparam CMD_IO_WIDTH = 64;
  
  localparam BSM_WRITE	= 8'h40;
  localparam BSM_READ	= 8'h30;
  localparam QUERY		= 8'h70;
  
  localparam CMD_ST_READ_DONE	= 6;	 
  localparam CMD_ST_WRITE_DONE 	= 7;
  localparam CMD_ST_READY2FREE 	= 12; 
 
  reg						tb_clk, tb_reset; 
  reg [CMD_IO_WIDTH-1:0]	tb_cmd_in;	
  reg 						tb_cmd_ie, tb_cmd_request;
  wire						tb_cmd_oe, tb_cq_cin_ready, tb_cq_cout_ready;
  wire [CMD_IO_WIDTH-1:0]	tb_cmd_out;
  reg [7:0]					tb_op_index, tb_cmd_op_status;	
  reg						tb_tbm_ie;
  reg [7:0]					tb_tbm_index;
  reg [31:0]				tb_tbm_address;
  reg						tb_query_ie;
  reg [7:0]					tb_query_tag;
  wire						tb_query_oe;
  wire [CMD_IO_WIDTH-1:0]	tb_query_out;	
  
  hv_commandQ	dut (
  				.clk(tb_clk),
  				.reset(tb_reset),
  				.cmd_ie(tb_cmd_ie),
  				.cmd_in(tb_cmd_in),
  				.cmd_request(tb_cmd_request),
  				.cmd_oe(tb_cmd_oe),
  				.cmd_out(tb_cmd_out),
  				.cq_cin_ready(tb_cq_cin_ready),
  				.cq_cout_ready(tb_cq_cout_ready),
  				.op_index(tb_op_index),
  				.cmd_op_status(tb_cmd_op_status),
  				.tbm_ie(tb_tbm_ie),
  				.tbm_index(tb_tbm_index),
  				.tbm_address(tb_tbm_address),
  				.query_ie(tb_query_ie),
  				.query_tag(tb_query_tag),
  				.query_oe(tb_query_oe),
  				.query_out(tb_query_out)
  );
  
  reg [7:0]		tb_tag_head, tb_tag_tail;
  reg [255:0]	tb_cdb, op_cdb, query_response;
  
  always 
  	begin 
  		#(CLK_HALF_PERIOD);
  		tb_clk = !tb_clk;
  	end
  	
  task build_n_transfer_cdb (input reg [7:0] op);
  	reg [15:0] i; 
  	begin
  		for (i = 0; i < 256; i = i + 32)
  			begin
  				tb_cdb [i +: 32] = 32'h00000000;
  			end
  			
  		// fill in the required fields 	
  		tb_cdb [7:0]	= op; // write
  		tb_cdb [15:08] 	= tb_tag_head;
  			
  		// calculate checksum	
  		tb_cdb [135:128] = tb_cdb[07:00] ^ tb_cdb[39:32] ^ tb_cdb[71:64] ^ tb_cdb[103:096] ^ tb_cdb[167:160] ^ tb_cdb[199:192] ^ tb_cdb[231:224];
  		tb_cdb [143:136] = tb_cdb[15:08] ^ tb_cdb[47:40] ^ tb_cdb[79:72] ^ tb_cdb[111:104] ^ tb_cdb[175:168] ^ tb_cdb[207:200] ^ tb_cdb[239:232];
  		tb_cdb [151:144] = tb_cdb[23:16] ^ tb_cdb[55:48] ^ tb_cdb[87:80] ^ tb_cdb[119:112] ^ tb_cdb[183:176] ^ tb_cdb[215:208] ^ tb_cdb[247:240];
  		tb_cdb [159:152] = tb_cdb[31:24] ^ tb_cdb[63:56] ^ tb_cdb[95:88] ^ tb_cdb[127:120] ^ tb_cdb[191:184] ^ tb_cdb[223:216] ^ tb_cdb[255:248];
  	
  	tb_cmd_ie = 1'b1;
  	tb_cmd_in = tb_cdb[63:0];
  	#(CLK_PERIOD);
  	tb_cmd_in = tb_cdb[127:64];
  	#(CLK_PERIOD);
  	tb_cmd_in = tb_cdb[191:128];
  	#(CLK_PERIOD);
  	tb_cmd_in = tb_cdb[255:192];
  	#(CLK_PERIOD);
  	tb_cmd_ie = 1'b0;
 	
 	tb_tag_head 	= tb_tag_head + 1;
  	end
  endtask 
  
  task process_command();
  	reg [15:0]	j;
  	begin
  		while (!tb_cq_cout_ready) 
  			begin
  				#(CLK_PERIOD);	
  			end
  		
  		//	tb_cmd_request MUST remain "1" only for 1-cycle.
  		tb_cmd_request = 1'b1;
  		#(CLK_PERIOD);
  		tb_cmd_request = 1'b0;
  		
  		while (!tb_cmd_oe)
  			begin
  				#(CLK_PERIOD);
  			end 
  		for (j = 0; j < 256; j = j + 64)	
  			begin 
  				op_cdb [j +: 64] = tb_cmd_out;
  				$display ("CDB (%d): %X", j, tb_cmd_out);
  				#(CLK_PERIOD);
  			end
  			
  			tb_cmd_op_status 	= CMD_ST_WRITE_DONE;
  			tb_op_index			= tb_tag_tail;	
  			tb_tag_tail 		= tb_tag_tail + 1;
  	end 	
  endtask
  
  task query_command();
  	reg [15:0] k;
  	begin
  		tb_query_ie = 1;
  		tb_query_tag = 0;
  		#(CLK_PERIOD);
  		tb_query_ie = 0;
  		
  		while (!tb_query_oe)
  			begin
  				#(CLK_PERIOD);
  			end
  		
  		for (k = 0; k < 256; k = k + 64)
  			begin
  				query_response[k +: 64] = tb_query_out;
  				$display("QR (%d): %X", k, tb_query_out);
  				#(CLK_PERIOD);
  			end
  	end
  endtask
  
  task update_command_status(input reg [7:0] status, input reg [7:0] cmd_index);
  	begin
  			tb_cmd_op_status 	= status;
  			tb_op_index			= cmd_index;
  			#(CLK_PERIOD);	
  	end
  endtask
  
  
  initial 
    begin 
      tb_clk = 0; 
      tb_tag_head = 0;
      tb_tag_tail = 0; 
      tb_query_ie = 0;
      
      tb_reset = 1'b1; 
      #(CLK_PERIOD); 
      tb_reset = 1'b0; 
      #(CLK_PERIOD);	
   
      build_n_transfer_cdb(BSM_WRITE); 
      build_n_transfer_cdb(BSM_WRITE); 
      build_n_transfer_cdb(BSM_WRITE); 
    
      process_command();
      process_command();
      process_command();
      
      query_command();
      // In the case of write command, after processing query command, command queue will release the command.
      // In the case of read command, after processing query command, the command's status is "TX_READY". Hence
      // command processing module transfers data from TBM to host and then have to update the status of the command 
      // "READY2FREE". 
      // update_command_status ( READY2FREE, xxx);
    end 
endmodule