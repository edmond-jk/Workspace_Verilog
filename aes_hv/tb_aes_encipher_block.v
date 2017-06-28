module tb_aes_encipher_block ();
	localparam	CLK_HALF_PERIOD	= 1;
	localparam	CLK_PERIOD = 2 * CLK_HALF_PERIOD;
  
  
  reg				tb_clk;
  reg				tb_reset_key, tb_reset_ecipher_1;
  wire				tb_ready_key, tb_ready_ecipher_1;
  reg [127:0]		tb_key;
  reg [127:0]		tb_block;
  wire [127:0]		tb_round_key [0:10];
  wire [127:0]		tb_in_sblock [0:10];
  wire [127:0]		tb_out_sblock [0:10];
  wire  [127:0]		tb_in_dblock[0:9];
  wire  [127:0]		tb_out_dblock[0:9];
  wire				tb_output_ctrl;
  
  
  aes_keymap	keymap (
  				.clk(tb_clk),
  				.reset_n(tb_reset_key),
  				.key(tb_key),
  				.sboxw(tb_in_sblock[0]),
  				.new_sboxw(tb_out_sblock[0]),
  				.round_key_0(tb_round_key[0]),
  				.round_key_1(tb_round_key[1]),
  				.round_key_2(tb_round_key[2]),
  				.round_key_3(tb_round_key[3]),
  				.round_key_4(tb_round_key[4]),
  				.round_key_5(tb_round_key[5]),
  				.round_key_6(tb_round_key[6]),
  				.round_key_7(tb_round_key[7]),
  				.round_key_8(tb_round_key[8]),
  				.round_key_9(tb_round_key[9]),
  				.round_key_10(tb_round_key[10]),
  				.ready(tb_ready_key)
  );
  
  aes_sbox	sbox (
  				.in_block_0(tb_in_sblock[0]), 
  				.in_block_1(tb_in_sblock[1]),
  				.in_block_2(tb_in_sblock[2]),
  				.in_block_3(tb_in_sblock[3]),
  				.in_block_4(tb_in_sblock[4]),
  				.in_block_5(tb_in_sblock[5]),
  				.in_block_6(tb_in_sblock[6]),
  				.in_block_7(tb_in_sblock[7]),
  				.in_block_8(tb_in_sblock[8]),
  				.in_block_9(tb_in_sblock[9]),
  				.in_block_10(tb_in_sblock[10]),
  				.out_block_0(tb_out_sblock[0]),
  				.out_block_1(tb_out_sblock[1]),
  				.out_block_2(tb_out_sblock[2]),
  				.out_block_3(tb_out_sblock[3]),
  				.out_block_4(tb_out_sblock[4]),
  				.out_block_5(tb_out_sblock[5]),
  				.out_block_6(tb_out_sblock[6]),
  				.out_block_7(tb_out_sblock[7]),
  				.out_block_8(tb_out_sblock[8]),
  				.out_block_9(tb_out_sblock[9]),
  				.out_block_10(tb_out_sblock[10])
  );
   
  aes_encipher_block dut (
  				.clk(tb_clk),
  				.reset_n(tb_reset_ecipher_1),
  				.round_key(tb_round_key[1]),
  				.old_sbox(tb_in_sblock[1]),
  				.new_sbox(tb_out_sblock[1]),
  				.input_block(tb_in_dblock[0]),
  				.output_block(tb_out_dblock[0]),
  				.output_ctrl(tb_output_ctrl),
  				.ready(tb_ready_ecipher_1)
  );
  
  assign tb_in_dblock[0] = tb_block;
 
  // Clock 
  always 
  	begin
  		#(CLK_HALF_PERIOD);
  		tb_clk = !tb_clk;
  	end 
  
  // Key words generation
  initial  
  begin
  	tb_clk = 0;
  	tb_reset_key = 1;
//  	tb_key = 128'h00000000_00000000_00000000_00000000;
  	tb_key = 128'h2b7e1516_28aed2a6_abf71588_09cf4f3c;
  	
  	#(CLK_PERIOD);
  	tb_reset_key = 0;
  	
  	while (!tb_ready_key)
  		begin
  			#(CLK_PERIOD);
  		end
 
  tb_block = 128'h193de3be_a0f4e22b_9ac68d2a_e9f84808;
  tb_reset_ecipher_1 = 1'b1; 	
  #(CLK_PERIOD);
  tb_reset_ecipher_1 = 1'b0;
  
  while (!tb_ready_ecipher_1)
  	begin
  		#(CLK_PERIOD);
  	end
  end
  
  
endmodule