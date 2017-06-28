module tb_aes_core();
  localparam CLK_HALF_PERIOD = 1; 
  localparam CLK_PERIOD = 2 * CLK_HALF_PERIOD;
	
  reg					tb_clk;
  reg					tb_reset_key;
  reg					tb_reset_enc, tb_reset_dec;
  reg [127:0]			tb_key;	
  wire					tb_ready_key;
  reg [127:0]			tb_block_enc, tb_block_dec, tb_encrypted_data;
  wire					tb_iready_enc, tb_iready_dec;
  wire					tb_oready_enc, tb_oready_dec;
 
  wire [127:0]			tb_result_enc, tb_result_dec; 
  
  aes_core	dut (
  			.clk(tb_clk),
  			.reset_key(tb_reset_key),
  			.reset_enc(tb_reset_enc),
  			.reset_dec(tb_reset_dec),
  			.key(tb_key),
  			.ready_key(tb_ready_key),
  			.block_enc(tb_block_enc),
  			.block_dec(tb_block_dec),
  			.iready_enc(tb_iready_enc),
  			.iready_dec(tb_iready_dec),
  			.oready_enc(tb_oready_enc),
  			.oready_dec(tb_oready_dec),
  			.result_enc(tb_result_enc),
  			.result_dec(tb_result_dec)
  );

  // Clock
  always
  	begin
  		#(CLK_HALF_PERIOD);
  		tb_clk = !tb_clk;
  	end  
  	
  	initial 
  	begin
  		tb_clk = 0;
  		tb_reset_key = 1;
  		tb_reset_enc = 0;
  		tb_reset_dec = 0;
  	
  		//tb_key = 128'h00000000_00000000_00000000_00000000;	
  		//tb_key = 128'h2b7e1516_28aed2a6_abf71588_09cf4f3c;
  		tb_key = 128'h00010203_04050607_08090a0b_0c0d0e0f;
  		#(CLK_PERIOD);
  		tb_reset_key = 0;
  		
  		while (!tb_ready_key)
  			begin
  				#(CLK_PERIOD);
  			end
  		
  		//tb_block_enc = 128'h3243f6a8_885a308d_313198a2_e0370734;
  		tb_block_enc = 128'h00112233_44556677_8899aabb_ccddeeff;
  		tb_reset_enc = 1'b1;
  		#(CLK_PERIOD);
  		tb_reset_enc = 1'b0;
  		#(CLK_PERIOD);
  		tb_reset_enc = 1'b1;
  		tb_block_enc = 128'h3243f6a8_885a308d_313198a2_e0370734;
  		#(CLK_PERIOD);
  		tb_reset_enc = 1'b0;
  		
  		while (!tb_oready_enc)
  			begin
  				#(CLK_PERIOD);
  			end
  		tb_encrypted_data = tb_result_enc;
  		
  		tb_block_dec = tb_encrypted_data;
  		tb_reset_dec = 1'b1;
  		#(CLK_PERIOD);
  		tb_reset_dec = 1'b0;
  		while (!tb_oready_dec)
  			begin
  				#(CLK_PERIOD);
  			end
  	end
endmodule