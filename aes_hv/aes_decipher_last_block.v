module aes_decipher_last_block (
	input wire				clk,
	input wire				reset_n,
	
	input wire [127:0]		round_key,
	
	output wire [127:0]		old_sbox,
	output wire [127:0]		new_sbox,
	
	input wire [127:0]		input_block,
	output wire [127:0]		output_block,
	output wire				output_ctrl, // to deliver data to the next encipher block
	output wire				ready	// notify ready state to the previous encipher block			
  );
  
  localparam Ns = 3;
  
  localparam InvSHIFTROWS	= 4'h0;
  localparam InvSUBBYTES	= 4'h1;
  localparam ADDROUNDKEY	= 4'h2;
  
  reg [127:0] 				i_round_block[0:Ns-1], o_round_block[0:Ns-1] ;
  reg						v_invshiftrows, v_invsubbytes, v_addroundkey;
 
  assign old_sbox 			= o_round_block[InvSHIFTROWS];
  assign ready				= !v_invshiftrows;
  assign output_ctrl		= v_addroundkey;
  assign output_block		= o_round_block[ADDROUNDKEY];
  
  initial 
  begin
  	v_invshiftrows 	<= 1'b0;
  	v_invsubbytes	<= 1'b0;
  	v_addroundkey	<= 1'b0;
  end
  
  // Round functions
  function [127:0] inv_shiftrows(input [127:0] data);
  	reg [31:0] w0, w1, w2, w3;
  	reg [31:0] ws0, ws1, ws2, ws3;
  	
  	begin
  		w0 = data[127:096];
  		w1 = data[095:064];
  		w2 = data[063:032];
  		w3 = data[031:000];
  		
  		ws0 = {w0[31:24], w3[23:16], w2[15:08], w1[07:00]};
  		ws1 = {w1[31:24], w0[23:16], w3[15:08], w2[07:00]};
  		ws2 = {w2[31:24], w1[23:16], w0[15:08], w3[07:00]};
  		ws0 = {w3[31:24], w2[23:16], w1[15:08], w0[07:00]};
  		
  		inv_shiftrows = {ws0, ws1, ws2, ws3};
  	end
  endfunction
  
  function [127:0] addroundkey (input [127:0] data, input [127:0] rkey);
  	begin
  		addroundkey = data ^ rkey;
  	end
  endfunction
  
  
  // Inverse shiftrows
  always @ (posedge clk or negedge reset_n)
  	begin: invshiftrows
  		if (reset_n)
  			begin 
  				i_round_block[InvSHIFTROWS] = input_block;
  				v_invshiftrows = 1'b1;
  				o_round_block[InvSHIFTROWS] =  inv_shiftrows (i_round_block[InvSHIFTROWS]);
  				$display ("INV_SHIFTROWS> %X", o_round_block[InvSHIFTROWS]);
  			end	
  		else
  			begin
  				v_invshiftrows = 1'b0;
  				$display ("INV_SHIFTROWS> 0x---");
  			end
  	end
  
  always @ (posedge clk)
  	begin: invsubbytes
  		if (v_invshiftrows)
  			begin	
  				i_round_block[InvSUBBYTES] 	= new_sbox;
  		
  				v_invsubbytes 				= 1'b1;
  				o_round_block[InvSUBBYTES] 	= i_round_block[InvSUBBYTES];
  				$display("INV_SUBBYTES> %X", o_round_block[InvSUBBYTES]);
  			end
  		else 
  			begin
  				v_invsubbytes 				= 1'b0;
  				$display("INV_SUBBYTES> 0x---");
  			end
  	end
  	
  always @ (posedge clk) 
  	begin: add_roundkey 
  		if(v_invsubbytes) 
  			begin
				i_round_block[ADDROUNDKEY] =  o_round_block[InvSUBBYTES];
				v_addroundkey 			= 1'b1;
				o_round_block[ADDROUNDKEY] = addroundkey(i_round_block[ADDROUNDKEY], round_key);
				$display("ADD_ROUNDKEY> %X", o_round_block[ADDROUNDKEY]);
  			end	
  		else
  			begin
  				v_addroundkey			= 1'b0;
  				$display("ADDROUNDKEY> 0x---");
  			end
  	end

endmodule