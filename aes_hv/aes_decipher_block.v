module aes_decipher_block (
	input wire				clk,
	input wire				reset_n,
	
	input wire [127:0]		round_key,
	
	output wire [127:0]		old_sbox,
	input wire [127:0]		new_sbox,
	
	input wire [127:0]		input_block,
	output wire [127:0]		output_block,
	output wire				oready, // to deliver data to the next encipher block
	output wire				iready	// notify ready state to the previous encipher block			
  );
  
  reg [127:0]		input_buffer;
  reg				tmp_iready;
  reg				tmp_reset_invshift;
  
  wire				reset_invshift, reset_invsub, reset_add, reset_invmix;
  wire				iready_invshift, iready_invsub, iready_add, iready_invmix;
  wire				oready_invshift, oready_invsub, oready_add, oready_invmix;
  
  wire [127:0]		data_invshift, data_invsub, data_add, data_invmix;
  wire [127:0]		result_invshift, result_invsub, result_add, result_invmix; 
  
  aes_invshiftrows invshiftrowsBlock (
  							.clk(clk),
  							.reset_n(reset_invshift),	
  							.data(data_invshift),
  							.result(result_invshift),
  							.iready(iready_invshift),
  							.oready(oready_invshift)
  ); 
  
  aes_invsubbytes invsubbytesBlock (
  							.clk(clk),
  							.reset_n(reset_invsub),
  							.data(data_invsub),
  							.old_sbox(old_sbox),
  							.new_sbox(new_sbox),
  							.result(result_invsub),
  							.iready(iready_invsub),
  							.oready(oready_invsub)
  );
  
  aes_addroundkey addroundkeyBlock (
  							.clk(clk),
  							.reset_n(reset_add),
  							.round_key(round_key),
  							.data(data_add),
  							.result(result_add),
  							.iready(iready_add),
  							.oready(oready_add)
  );
  
  aes_invmixcolumns invmixcolumnsBlock (
  							.clk(clk),
  							.reset_n(reset_invmix),
  							.data(data_invmix),
  							.result(result_invmix),
  							.iready(iready_invmix),
  							.oready(oready_invmix)
  );
  
  // connections for the entire module
  assign iready = !tmp_iready;
  
  // connections among each function blocks
  assign reset_invshift 	= tmp_reset_invshift;
  assign reset_invsub 		= oready_invshift;
  assign reset_add 			= oready_invsub;
  assign reset_invmix 		= oready_add;
  assign oready				= oready_invmix;
  
  assign data_invshift		= input_buffer;
  assign data_invsub		= result_invshift;
  assign data_add			= result_invsub; 
  assign data_invmix		= result_add;
  assign output_block		= result_invmix;
  
  initial 
  begin
  	tmp_iready = 1'b0;
  	tmp_reset_invshift = 1'b0;
  end
  
  always @ (posedge clk)
  begin
  	if (reset_n)
  		begin
  			input_buffer = input_block;
  			tmp_iready = 1'b1;
  			tmp_reset_invshift = 1'b1;
  		end
  	else
  		begin
  			tmp_iready = 1'b0;
  			tmp_reset_invshift = 1'b0;
  		end
  end
endmodule