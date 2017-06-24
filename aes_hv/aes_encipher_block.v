module aes_encipher_block (
	input wire				clk,
	input wire				reset_n,

	input wire [3:0]		round,	
	input wire [127:0]		round_key,

	output wire [127:0] 	input_sbox, // input block to sbox
	input wire [127:0] 		output_sbox,	
	
	input wire [127:0]  	input_block,
	output wire [127:0]		output_block,
	output wire				output_ctrl, // to deliver data to the next encipher block	
	output wire				ready	// notify ready state to the previous  encipher block
	);
	
	localparam Ns = 4; // number of states in a round
	// states	
	localparam IDLE 		= 4'h0;
	localparam SUBBYTE 		= 4'h1;
	localparam SHIFTROWS	= 4'h2;
	localparam MIXCOLUMNS 	= 4'h3;
	localparam ADDROUNDKEY	= 4'h4;	
	
	
	reg [127:0]				round_block, tmp_block, tmp_output_block;
	
	reg [3:0]				current_state;
	reg						tmp_ready, tmp_output_ctrl;
	
	assign input_sbox 		= input_block; // data substitution when data coming  . 
	assign ready			= tmp_ready;
	assign output_ctrl		= tmp_output_ctrl;	
	assign	output_block	= tmp_output_block; 

	initial 
	begin
		tmp_ready 		<= 1'b1;
		current_state  	<= IDLE;
		tmp_output_ctrl <= 1'b0;
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
	
	always @ (posedge clk or negedge reset_n)
		begin: sub_byte
			if (!reset_n)
				begin
					round_block 	= output_sbox;
					tmp_ready 		= 1'b0;
					tmp_output_ctrl 	= 1'b0;	
					current_state  	= SHIFTROWS;
				end
		end
	
	always @ (posedge clk)
		begin
			case (current_state)
				SHIFTROWS:
					begin
						tmp_block 		= shiftRows(round_block);
						current_state 	= MIXCOLUMNS;
					end
				MIXCOLUMNS:
					begin
						round_block		= mixcolumns(tmp_block);
					end
				ADDROUNDKEY:
					begin
						tmp_block 			= addroundkey(round_block, round_key);
						tmp_output_block 	= tmp_block;
						tmp_output_ctrl 	= 1'b1;
						tmp_ready			= 1'b1;	
					end
				IDLE:
					begin
						tmp_output_ctrl 	= 1'b0;	
					end
			endcase
		end
endmodule