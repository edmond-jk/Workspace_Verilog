module aes_encipher_block (
	input wire				clk,
	input wire				reset_n,
 	
 	input wire [3:0]		round,
	input wire [127:0]		round_key,

	output wire [127:0] 	old_sbox, // input block to sbox
	input wire [127:0] 		new_sbox,	
	
	input wire [127:0]  	input_block,
	output wire [127:0]		output_block,
	output wire				output_ctrl, // to deliver data to the next encipher block	
	output wire				ready	// notify ready state to the previous  encipher block
	);
	
	localparam Ns = 4; // number of states in a round
	// buffers allocated to each state	
	localparam SUBBYTE 		= 4'h0;
	localparam SHIFTROWS	= 4'h1;
	localparam MIXCOLUMNS 	= 4'h2;
	localparam ADDROUNDKEY	= 4'h3;	
	
	
	reg [127:0]				i_round_block[0:Ns-1], o_round_block[0:Ns-1];
	
	reg						v_subbyte, v_shiftrows, v_mixcolumns, v_addroundkey;
	
	assign old_sbox 		= input_block; // data substitution when data coming  . 
	assign ready			= !v_subbyte;
	assign output_ctrl		= v_addroundkey;	
	assign output_block		= o_round_block[ADDROUNDKEY];

	initial 
	begin
		v_subbyte 		<= 1'b0;
		v_shiftrows		<= 1'b0;
		v_mixcolumns	<= 1'b0;
		v_addroundkey	<= 1'b0;
	end 

	/*
	 * Round functions
	 */	
	function [127:0] shiftRows(input [127:0] data);
		reg [31:0]	w0, w1, w2, w3;
		reg [31:0]	ws0, ws1, ws2, ws3;
		begin
			w0 = data[127 : 096];
			w1 = data[095 : 064];
			w2 = data[063 : 032];
			w3 = data[031 : 000];
			
			ws0 = {w0[31:24], w1[23:16], w2[15:08], w3[07:00]};
			ws1 = {w1[31:24], w2[23:16], w3[15:08], w0[07:00]};
			ws2 = {w2[31:24], w3[23:16], w0[15:08], w1[07:00]};
			ws3 = {w3[31:24], w0[23:16], w1[15:08], w2[07:00]};
			
			shiftRows = {ws0, ws1, ws2, ws3};
		end
	endfunction
	
	function [7:0] gm2(input [7:0] op);
		begin 
			gm2 = {op[6:0], 1'b0} ^ (8'h1b & {8{op[7]}});
		end
	endfunction
	
	function [7:0] gm3(input [7:0] op);
		begin
			gm3 = gm2(op) ^ op;
		end	
	endfunction
	
	function [31:0] mixw(input [31:0] w);
		reg [7:0] b0, b1, b2, b3;
		reg [7:0] mb0, mb1, mb2, mb3;
		begin
			b0 = w[31:24];
			b1 = w[23:16];
			b2 = w[15:08];
			b3 = w[07:00];
			
			mb0 = gm2(b0) ^ gm3(b1) ^ b2      ^ b3;
			mb1 = b0	  ^	gm2(b1) ^ gm3(b2) ^ b3;
			mb2 = b0	  ^ b1      ^ gm2(b2) ^ gm3(b3);
			mb3 = gm3(b0) ^ b1 		^ b2	  ^ gm2(b3);
		
			mixw = {mb0, mb1, mb2, mb3};
		end
	endfunction
	
	function [127:0] mixcolumns(input [127:0] data);
		reg [31:0] w0, w1, w2, w3;
		reg [31:0] ws0, ws1, ws2, ws3;
		
		begin
			w0 = data[127:096];
			w1 = data[095:064];
			w2 = data[063:032];
			w3 = data[031:000];
			
			ws0 = mixw(w0);
			ws1 = mixw(w1);
			ws2 = mixw(w2);
			ws3 = mixw(w3);
			
			mixcolumns = {ws0, ws1, ws2, ws3};
		end
	endfunction
	
	function [127:0]  addroundkey(input [127:0] data, input [127:0] rkey);
		begin
			addroundkey = data ^ rkey;
		end
	endfunction 

	/*
	 * SubByte routine
	 */	
	always @ (posedge clk or negedge reset_n)
		begin: sub_byte
			if (reset_n)
				begin
					i_round_block[SUBBYTE] 	= new_sbox;
					
					v_subbyte 				= 1'b1;
					o_round_block[SUBBYTE]	= i_round_block[SUBBYTE];
					$display("SubByte(%d):%d> %X", round, $time, o_round_block[SUBBYTE]);
				end
			else
				begin
					v_subbyte <= 1'b0;
//					$display("SubByte> 0x---");
				end
		end
	
	/*
	 * ShiftRows routine
	 */
	always @ (posedge clk)
	 	begin
	 		if (v_subbyte)
	 			begin
	 				i_round_block[SHIFTROWS]	= o_round_block[SUBBYTE];
	 			
	 				v_shiftrows 				= 1'b1;
	 				o_round_block[SHIFTROWS] 	= shiftRows(i_round_block[SHIFTROWS]);
					$display("ShiftRows(%d):%d> %X", round, $time,  o_round_block[SHIFTROWS]);
	 			end
	 		else
	 			begin 
	 				v_shiftrows	<= 1'b0;
//					$display("ShiftRows> 0x--- ");
	 			end
	 	end
	 	
	/*
	 * MixColumns routine
	 */
	always @  (posedge clk)
		begin
			if (v_shiftrows)
				begin
					i_round_block[MIXCOLUMNS] 	= o_round_block[SHIFTROWS];
				
					v_mixcolumns 				= 1'b1;
					o_round_block[MIXCOLUMNS] 			= mixcolumns(i_round_block[MIXCOLUMNS]);
					$display("MixColumns(%d):%d> %X", round, $time, o_round_block[MIXCOLUMNS]);
				end
			else
				begin
					v_mixcolumns <= 1'b0;
//					$display("MixColumns> 0X---");
				end
		end
	
	/*
	 * AddRoundKey routine
	 */
	always @ (posedge clk)
		begin
			if (v_mixcolumns)
				begin
					i_round_block[ADDROUNDKEY]	= o_round_block[MIXCOLUMNS];
					
					v_addroundkey		= 1'b1;
					o_round_block[ADDROUNDKEY]	= addroundkey(i_round_block[ADDROUNDKEY], round_key);
					$display("AddRoundKey(%d):%d> %X", round, $time, o_round_block[ADDROUNDKEY]);
				end
			else
				begin
					v_addroundkey		= 1'b0;
//					$display("AddRoundKey> 0x---");
				end
		end
	
endmodule