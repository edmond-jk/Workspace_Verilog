module aes_core (
	input wire				clk,
	input wire				reset_key, 
	
	input wire				reset_enc, 
	input wire				reset_dec, 
	
	input wire [127:0]		key,
	output wire				ready_key,	
	
	input wire [127:0]		block_enc,
	input wire [127:0]		block_dec,
	
	output wire				iready_enc,
	output wire				iready_dec,
	
	output wire				oready_enc,
	output wire				oready_dec,

	output wire [127:0]		result_enc,
	output wire [127:0]		result_dec
);

  localparam N_aesblock = 10; // the number of encipher blocks
  wire				reset_encipher[0:N_aesblock], ready_encipher[0:N_aesblock];
  wire [127:0]		round_key [0:N_aesblock];
  wire [127:0]		in_sblk [0:N_aesblock];
  wire [127:0]		out_sblk [0:N_aesblock];
  wire [127:0]		in_dblk_enc[0:N_aesblock]; // input data block for encipher
  wire [127:0]		out_dblk_enc[0:N_aesblock]; // output data block for encipher
  wire				octrl_enc[0:N_aesblock]; // octrl_enc

  wire				reset_decipher[0:N_aesblock], ready_decipher[0:N_aesblock];
  wire [127:0]		in_invsblk [0:N_aesblock];
  wire [127:0]		out_invsblk [0:N_aesblock];
  wire [127:0]		in_dblk_dec[0:N_aesblock]; // input data block for decipher
  wire [127:0]		out_dblk_dec[0:N_aesblock]; // output data block for decipher
  wire				octrl_dec[0:N_aesblock]; // octrl_dec
  
  reg 				v_in_encblk, v_in_decblk;
  reg [127:0]		tmp_out_dblk_enc, tmp_out_dblk_dec;
  reg				tmp_reset_encipher, tmp_reset_decipher;

  aes_sbox	sbox (
  			.in_block_0(in_sblk[0]), 
  			.in_block_1(in_sblk[1]),
  			.in_block_2(in_sblk[2]),
  			.in_block_3(in_sblk[3]),
  			.in_block_4(in_sblk[4]),
  			.in_block_5(in_sblk[5]),
  			.in_block_6(in_sblk[6]),
  			.in_block_7(in_sblk[7]),
  			.in_block_8(in_sblk[8]),
  			.in_block_9(in_sblk[9]),
  			.in_block_10(in_sblk[10]),
  			.out_block_0(out_sblk[0]),
  			.out_block_1(out_sblk[1]),
  			.out_block_2(out_sblk[2]),
  			.out_block_3(out_sblk[3]),
  			.out_block_4(out_sblk[4]),
  			.out_block_5(out_sblk[5]),
  			.out_block_6(out_sblk[6]),
  			.out_block_7(out_sblk[7]),
  			.out_block_8(out_sblk[8]),
  			.out_block_9(out_sblk[9]),
  			.out_block_10(out_sblk[10])
  );

  aes_inv_sbox	inv_sbox (
  			.in_block_0(in_invsblk[0]), 
  			.in_block_1(in_invsblk[1]),
  			.in_block_2(in_invsblk[2]),
  			.in_block_3(in_invsblk[3]),
  			.in_block_4(in_invsblk[4]),
  			.in_block_5(in_invsblk[5]),
  			.in_block_6(in_invsblk[6]),
  			.in_block_7(in_invsblk[7]),
  			.in_block_8(in_invsblk[8]),
  			.in_block_9(in_invsblk[9]),
  			.in_block_10(in_invsblk[10]),
  			.out_block_0(out_invsblk[0]),
  			.out_block_1(out_invsblk[1]),
  			.out_block_2(out_invsblk[2]),
  			.out_block_3(out_invsblk[3]),
  			.out_block_4(out_invsblk[4]),
  			.out_block_5(out_invsblk[5]),
  			.out_block_6(out_invsblk[6]),
  			.out_block_7(out_invsblk[7]),
  			.out_block_8(out_invsblk[8]),
  			.out_block_9(out_invsblk[9]),
  			.out_block_10(out_invsblk[10])
  );
  aes_keymap keymap (
  			.clk(clk),
  			.reset_n(reset_key),
  			.key(key),
  			.sboxw(in_sblk[0]),
  			.new_sboxw(out_sblk[0]),
  			.round_key_0(round_key[0]),
  			.round_key_1(round_key[1]),
  			.round_key_2(round_key[2]),
  			.round_key_3(round_key[3]),
  			.round_key_4(round_key[4]),
  			.round_key_5(round_key[5]),
  			.round_key_6(round_key[6]),
  			.round_key_7(round_key[7]),
  			.round_key_8(round_key[8]),
  			.round_key_9(round_key[9]),
  			.round_key_10(round_key[10]),
  			.ready(ready_key)
  );
  
  genvar i;
  for (i = 1; i < N_aesblock; i = i + 1)
	begin
		aes_encipher_block encBlock (
			.clk(clk),
			.reset_n(reset_encipher[i]),
			.round_key(round_key[i]),
			.old_sbox(in_sblk[i]),
			.new_sbox(out_sblk[i]),
			.input_block(in_dblk_enc[i]),
			.output_block(out_dblk_enc[i]),
			.oready(octrl_enc[i]),
			.iready(ready_encipher[i])
		);
		
		aes_decipher_block decBlock (
			.clk(clk),
			.reset_n(reset_decipher[i]),
			.round_key(round_key[N_aesblock - i]),
			.old_sbox(in_invsblk[i]),
			.new_sbox(out_invsblk[i]),
			.input_block(in_dblk_dec[i]),
			.output_block(out_dblk_dec[i]),
			.oready(octrl_dec[i]),
			.iready(ready_decipher[i])
		);
	end 

  
  aes_encipher_last_block	encBlockLast (
  			.clk(clk),
  			.reset_n(reset_encipher[N_aesblock]),
  			.round_key(round_key[N_aesblock]),
  			.old_sbox(in_sblk[N_aesblock]),
  			.new_sbox(out_sblk[N_aesblock]), 
  			.input_block(in_dblk_enc[N_aesblock]),
  			.output_block(out_dblk_enc[N_aesblock]),
  			.oready(octrl_enc[N_aesblock]),
  			.iready(ready_encipher[N_aesblock])
  );
  aes_decipher_last_block decBlockLast (
			.clk(clk),
			.reset_n(reset_decipher[N_aesblock]),
			.round_key(round_key[0]),
			.old_sbox(in_invsblk[N_aesblock]),
			.new_sbox(out_invsblk[N_aesblock]),
			.input_block(in_dblk_dec[N_aesblock]),
			.output_block(out_dblk_dec[N_aesblock]),
			.oready(octrl_dec[N_aesblock]),
			.iready(ready_decipher[N_aesblock])
		);

  assign in_dblk_enc[0] = block_enc;
  assign reset_encipher[0] = reset_enc;
  assign iready_enc = !v_in_encblk;
  assign result_enc = out_dblk_enc[N_aesblock];
  
  assign in_dblk_dec[0] = block_dec;
  assign reset_decipher[0] = reset_dec;
  assign iready_dec = !v_in_decblk;
  assign result_dec = out_dblk_dec[N_aesblock];
  
  assign reset_encipher[1] = tmp_reset_encipher;
  assign reset_decipher[1] = tmp_reset_decipher; 
    
  for (i = 1; i < N_aesblock; i = i + 1)
 	begin
 		assign in_dblk_enc[i+1] = out_dblk_enc[i];
 		assign reset_encipher[i+1] = (ready_encipher[i+1]) ? octrl_enc[i] : 0;
 		
 		assign in_dblk_dec[i+1] = out_dblk_dec[i];
 		assign reset_decipher[i+1] = (ready_decipher[i+1]) ? octrl_dec[i] : 0;
 	end 
 	
  assign in_dblk_enc[1] = tmp_out_dblk_enc;
  assign oready_enc = octrl_enc[N_aesblock];
 
  assign in_dblk_dec[1] = tmp_out_dblk_dec;
  assign oready_dec = octrl_dec[N_aesblock];
  
  initial
  begin
  	tmp_reset_encipher 	= 1'b0;
  	tmp_reset_decipher 	= 1'b0;
  	v_in_encblk 	= 1'b0;
  	v_in_decblk 	= 1'b0;
  end
    
  always @ (posedge clk)
  	begin
  		if (reset_enc)
  			begin
  				tmp_reset_encipher = 1'b1;
  				
  				tmp_out_dblk_enc = in_dblk_enc[0] ^ round_key[0]; 
  				v_in_encblk = 1'b1;
  			end
  		else
  			begin
  				v_in_encblk = 1'b0;
  				tmp_reset_encipher = 1'b0;
  			end
  	end

  always @ (posedge clk)
  	begin
  		if (reset_dec)
  			begin
  				tmp_out_dblk_dec = in_dblk_dec[0] ^ round_key[10]; 
  				v_in_decblk = 1'b1;
  				tmp_reset_decipher = 1'b1;
  			end
  		else
  			begin
  				v_in_decblk = 1'b0;
  				tmp_reset_decipher = 1'b0;
  			end
  	end
endmodule