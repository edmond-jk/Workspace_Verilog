module aes_encipher_last_block (
	input wire				clk,
	input wire				reset_n,

	input wire [127:0]		round_key,

	output wire [127:0] 	old_sbox, // input block to sbox
	input wire [127:0] 		new_sbox,	
	
	input wire [127:0]  	input_block,
	output wire [127:0]		output_block,
	output wire				output_ctrl, // to deliver data to the next encipher block	
	output wire				ready	// notify ready state to the previous  encipher block
	);
	
	localparam Ns = 3; // number of states in a round
	// buffers allocated to each state	
	localparam SUBBYTE 		= 4'h0;
	localparam SHIFTROWS	= 4'h1;
	localparam ADDROUNDKEY	= 4'h2;	
	
	
	reg [127:0]				i_round_block[0:Ns-1], o_round_block[0:Ns-1];
	
	reg						v_subbyte, v_shiftrows, v_addroundkey;
	
	assign old_sbox 		= input_block; // data substitution when data coming  . 
	assign ready			= !v_subbyte;
	assign output_ctrl		= v_addroundkey;	
	assign output_block		= o_round_block[ADDROUNDKEY];

	initial 
	begin
		v_subbyte 		<= 1'b0;
		v_shiftrows		<= 1'b0;
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
					$display("SubByte> %X", o_round_block[SUBBYTE]);
				end
			else
				begin
					v_subbyte = 1'b0;
					$display("SubByte> 0x---");
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
					$display("ShiftRows> %X", o_round_block[SHIFTROWS]);
	 			end
	 		else
	 			begin 
	 				v_shiftrows	= 1'b0;
					$display("ShiftRows> 0x--- ");
	 			end
	 	end
	 	
	
	/*
	 * AddRoundKey routine
	 */
	always @ (posedge clk)
		begin
			if (v_shiftrows)
				begin
					i_round_block[ADDROUNDKEY]	= o_round_block[SHIFTROWS];
					
					v_addroundkey		= 1'b1;
					o_round_block[ADDROUNDKEY]	= addroundkey(i_round_block[ADDROUNDKEY], round_key);
					$display("AddRoundKey> %X", o_round_block[ADDROUNDKEY]);
				end
			else
				begin
					v_addroundkey		= 1'b0;
					$display("AddRoundKey> 0x---");
				end
		end
	
endmodule