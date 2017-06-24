module tb_aes_keymap();
	localparam	CLK_HALF_PERIOD = 1;
	localparam 	CLK_PERIOD = 2 * CLK_HALF_PERIOD;
	
  reg 				tb_clk;
  reg 				tb_reset_n;
  wire				tb_ready;
  reg [127:0]		tb_key;
  
  wire [127:0]		tb_sboxw;
  wire [127:0]		tb_new_sboxw;
  wire [127:0]		round_key [0:9];
  wire [31:0]		in_block[0:8];
  wire [31:0]		out_block[0:8];
  
  aes_keymap	dut (
  				.clk(tb_clk),
  				.reset_n(tb_reset_n),
  				.key(tb_key),
  				.sboxw(tb_sboxw),
  				.new_sboxw(tb_new_sboxw),
  				.round_key_1(round_key[0]),
  				.round_key_2(round_key[1]),
  				.round_key_3(round_key[2]),
  				.round_key_4(round_key[3]),
  				.round_key_5(round_key[4]),
  				.round_key_6(round_key[5]),
  				.round_key_7(round_key[6]),
  				.round_key_8(round_key[7]),
  				.round_key_9(round_key[8]),
  				.round_key_10(round_key[9]),
  				.ready(tb_ready)
  				
  );
  
  aes_sbox	sbox (
  				.in_block_0(tb_sboxw),
  				.out_block_0(tb_new_sboxw),
  				.in_block_1(in_block[0]),
  				.in_block_2(in_block[1]),
  				.in_block_3(in_block[2]),
  				.in_block_4(in_block[3]),
  				.in_block_5(in_block[4]),
  				.in_block_6(in_block[5]),
  				.in_block_7(in_block[6]),
  				.in_block_8(in_block[7]),
  				.in_block_9(in_block[8]),
  				.out_block_1(out_block[0]),
  				.out_block_2(out_block[1]),
  				.out_block_3(out_block[2]),
  				.out_block_4(out_block[3]),
  				.out_block_5(out_block[4]),
  				.out_block_6(out_block[5]),
  				.out_block_7(out_block[6]),
  				.out_block_8(out_block[7]),
  				.out_block_9(out_block[8])
  );
 
 // clock 
  always
  	begin
  		#(CLK_HALF_PERIOD);
  		tb_clk = !tb_clk;
  	end
  
  initial
  begin: aes_keymap_test
 	reg [127 : 0] expected_00;
    reg [127 : 0] expected_01;
    reg [127 : 0] expected_02;
    reg [127 : 0] expected_03;
    reg [127 : 0] expected_04;
    reg [127 : 0] expected_05;
    reg [127 : 0] expected_06;
    reg [127 : 0] expected_07;
    reg [127 : 0] expected_08;
    reg [127 : 0] expected_09;
    reg [127 : 0] expected_10;
  	
  	expected_00 = 128'h00000000000000000000000000000000; 
  	expected_01 = 128'h62636363626363636263636362636363;
    expected_02 = 128'h9b9898c9f9fbfbaa9b9898c9f9fbfbaa;
    expected_03 = 128'h90973450696ccffaf2f457330b0fac99;
    expected_04 = 128'hee06da7b876a1581759e42b27e91ee2b;
    expected_05 = 128'h7f2e2b88f8443e098dda7cbbf34b9290;
    expected_06 = 128'hec614b851425758c99ff09376ab49ba7;
    expected_07 = 128'h217517873550620bacaf6b3cc61bf09b;
    expected_08 = 128'h0ef903333ba9613897060a04511dfa9f;
    expected_09 = 128'hb1d4d8e28a7db9da1d7bb3de4c664941;
    expected_10 = 128'hb4ef5bcb3e92e21123e951cf6f8f188e;
   	
   	tb_clk = 0; 
    tb_reset_n	= 1;
  	tb_key = 128'h00000000_00000000_00000000_00000000;
  	#(CLK_PERIOD);
  	tb_reset_n = 0;
  	
  	while (!tb_ready)
  	begin
  		#(CLK_PERIOD);
  	end
   	
  	tb_reset_n	= 1;
  	tb_key = 128'h6920e299_a5202a6d_656e6368_69746f2a;
  	#(CLK_PERIOD);
  	tb_reset_n = 0;
  	
  	while (!tb_ready)
  	begin
  		#(CLK_PERIOD);
  	end
  	
  end
  	
endmodule