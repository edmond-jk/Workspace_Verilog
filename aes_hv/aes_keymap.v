module aes_keymap ( 
  input wire 			clk, 
  input wire 			reset_n, 
  input wire [127:0] 	key, // 128 bit 
  output wire [127:0]	sboxw, 
  input wire  [127:0] 	new_sboxw,

  output wire [127:0] 	round_key_1, 
  output wire [127:0] 	round_key_2, 
  output wire [127:0] 	round_key_3, 
  output wire [127:0] 	round_key_4, 
  output wire [127:0] 	round_key_5, 
  output wire [127:0] 	round_key_6, 
  output wire [127:0] 	round_key_7, 
  output wire [127:0] 	round_key_8, 
  output wire [127:0] 	round_key_9, 
  output wire [127:0] 	round_key_10, 

  output wire 			ready
  ); 
  
  localparam	Nr			= 10;// round number
  localparam 	Nk			= 4; // 128 bit key is 4 words
  localparam 	Nt 			= (Nr + 1) * Nk; // total count
  localparam	INIT		= 0;
  localparam	ROT_SUBW	= 1;
  localparam	MIXW		= 2;
  localparam 	DONE		= 3;
  
  reg [31:0] 			keymap [0:Nt-1];   
  reg [31:0]			target, rotw, subw, tmp_key; 
  reg [7:0]				current; 
  reg					tmp_ready;
  reg [31:0]			rcon[0:10];
  reg [31:0]			tmp_sboxw, updated_sboxw;
  reg [1:0]				current_state; // 4 states
  
  reg [7:0]				i;
  reg [4:0]				round_mod, round;
  
  assign ready = tmp_ready;
  assign sboxw = tmp_sboxw;
  
  assign round_key_1 	= {keymap[4],  keymap[5],  keymap[6],  keymap[7]};
  assign round_key_2 	= {keymap[8],  keymap[9],  keymap[10], keymap[11]};
  assign round_key_3 	= {keymap[12], keymap[13], keymap[14], keymap[15]};
  assign round_key_4 	= {keymap[16], keymap[17], keymap[18], keymap[19]};
  assign round_key_5 	= {keymap[20], keymap[21], keymap[22], keymap[23]};
  assign round_key_6 	= {keymap[24], keymap[25], keymap[26], keymap[27]};
  assign round_key_7 	= {keymap[28], keymap[29], keymap[30], keymap[31]};
  assign round_key_8 	= {keymap[32], keymap[33], keymap[34], keymap[35]};
  assign round_key_9	= {keymap[36], keymap[37], keymap[38], keymap[39]};
  assign round_key_10	= {keymap[40], keymap[41], keymap[42], keymap[43]};
  
  initial 
  begin
  	tmp_ready 		<= 1'b0;
  	current 		<= 0;
  	current_state 	<= INIT;
  	
  	// Create rcon array
  	rcon[1] = 	32'h01000000;
  	rcon[2] = 	32'h02000000;
  	rcon[3] = 	32'h04000000;
  	rcon[4] = 	32'h08000000;
  	rcon[5] = 	32'h10000000;
  	rcon[6] = 	32'h20000000;
  	rcon[7] = 	32'h40000000;
  	rcon[8] = 	32'h80000000;
  	rcon[9] = 	32'h1b000000;
  	rcon[10] = 	32'h36000000;
  end
  
  always @ (posedge clk or negedge reset_n) 
  begin 
  	if (reset_n)
  		begin
  			keymap[0] <= key[127:96];
  			keymap[1] <= key[95:64];
  			keymap[2] <= key[63:32];
  			keymap[3] <= key[31:0];
  			
  			current			= 8'h4; 
  			tmp_ready		= 1'b0;
  			round 			= 0;	
  			current_state 	<= ROT_SUBW;
  		end	
  end
  
  always @ (posedge clk)
  begin
  	case (current_state)
  		ROT_SUBW:
  			begin
  			 round		= round + 1;	
  			 rotw 		= {keymap[current-1][23:0], keymap[current-1][31:24]}; 
  			 tmp_sboxw 	= {96'b0,rotw}; 
  			 tmp_key	= keymap[current -4] ^ rcon[round]; 
  			 
  			 current_state = MIXW;
  			end
  		MIXW:
  			begin 
  				keymap[current] = tmp_key ^ new_sboxw[31:0]; 
  				current = current + 1; 
  				
  				while ((current & 8'h3)) 
  					begin
 						keymap[current] = keymap[current-1] ^ keymap[current-4];
		 				current = current + 1;
 					end
 				
 				if (current == Nt)
 					begin
 						tmp_ready = 1'b1;
 						current_state = INIT;
 					end
 				else
 					begin
 						current_state = ROT_SUBW;
 					end
  			end
  	endcase
  end 
  
endmodule