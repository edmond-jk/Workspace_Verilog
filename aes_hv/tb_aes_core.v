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

  task key_expansion_test (input [127:0] key);
  	begin
  		tb_reset_key = 1'b1;
  		tb_key = key;
  		#(CLK_PERIOD);
  		tb_reset_key = 1'b0;
  		
  		while (!tb_ready_key)
  			begin
  				#(CLK_PERIOD);
  			end
  	end
  endtask
  	
  initial 
  begin: aes_core_test
  // key value 
  	reg [127:0] 	nist_aes128_key;
  	reg [127:0]		nist_plaintext [0:3];
  	reg [127:0]		nist_enc_expected [0:3];
  	reg [127:0]		nist_encrypted [0:3];
  	reg [127:0]		nist_decrypted [0:3];
  	reg [3:0]		i;
  	
  	nist_aes128_key = 128'h2b7e1516_28aed2a6_abf71588_09cf4f3c;
   
  	nist_plaintext [0] = 128'h3243f6a8_885a308d_313198a2_e0370734; 	
   	nist_plaintext [1] = 128'hae2d8a57_1e03ac9c_9eb76fac_45af8e51;
    nist_plaintext [2] = 128'h30c81c46_a35ce411_e5fbc119_1a0a52ef;
    nist_plaintext [3] = 128'hf69f2445_df4f9b17_ad2b417b_e66c3710;	
  
  	nist_enc_expected [0] = 128'h3925841d_02dc09fb_dc118597_196a0b32;
    nist_enc_expected [1] = 128'hf5d3d585_03b9699d_e785895a_96fdbaaf;
    nist_enc_expected [2] = 128'h43b1cd7f_598ece23_881b00e3_ed030688;
    nist_enc_expected [3] = 128'h7b0c785e_27e8ad3f_82232071_04725dd4;
  	
  	tb_clk = 0; 
  	tb_reset_enc = 0; 
  	tb_reset_dec = 0;
  	
  	key_expansion_test(nist_aes128_key);
  	
  	tb_reset_enc = 1'b1;
  	tb_block_enc = nist_plaintext [0]; 
  	#(CLK_PERIOD); 
  	tb_block_enc = nist_plaintext [1]; 
  	#(CLK_PERIOD);
  	tb_block_enc = nist_plaintext [2]; 
  	#(CLK_PERIOD);
  	tb_block_enc = nist_plaintext [3]; 
  	#(CLK_PERIOD);
  	tb_reset_enc = 1'b0;
  		
  	while (!tb_oready_enc)
  		begin
  			#(CLK_PERIOD);
  		end
  	
  	i = 0;
  	
  	while (tb_oready_enc)
  		begin
  			nist_encrypted[i] = tb_result_enc;
  			i = i + 1;
  			#(CLK_PERIOD);
  		end
  		
  	tb_reset_dec = 1'b1;
  	tb_block_dec = nist_encrypted[0];
  	#(CLK_PERIOD);
  	tb_block_dec = nist_encrypted[1];
  	#(CLK_PERIOD);
  	tb_block_dec = nist_encrypted[2];
  	#(CLK_PERIOD);
  	tb_block_dec = nist_encrypted[3];
  	#(CLK_PERIOD);
  	tb_reset_dec = 1'b0;
  	
  	while (!tb_oready_dec)
  		begin
  			#(CLK_PERIOD);
  		end
  	
  	while (tb_oready_dec)
  		begin
  			#(CLK_PERIOD);
  		end
  	end
  	
endmodule