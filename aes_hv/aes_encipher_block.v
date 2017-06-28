module aes_encipher_block (
	input wire				clk,
	input wire				reset_n,
 	
	input wire [127:0]		round_key,

	output wire [127:0] 	old_sbox, // input block to sbox
	input wire [127:0] 		new_sbox,	
	
	input wire [127:0]  	input_block,
	output wire [127:0]		output_block,
	output wire				oready, // to deliver data to the next encipher block	
	output wire				iready	// notify ready state to the previous  encipher block
	);
	
    reg [127:0]				input_buffer;	
	reg						tmp_iready;
	reg						tmp_reset_shiftrows; 
	
	wire					reset_shiftrows, reset_mixcolumns, reset_addroundkey;	
	wire 					iready_shiftrows, iready_mixcolumns, iready_addroundkey;
	wire 					oready_shiftrows, oready_mixcolumns, oready_addroundkey;
	wire [127:0]			data_shiftrows, data_mixcolumns, data_addroundkey;
	wire [127:0]			result_shiftrows, result_mixcolumns, result_addroundkey;
	
	// function blocks
	aes_shiftrows shiftrowsBlock (
							.clk(clk),
							.reset_n(reset_shiftrows),
							.data(data_shiftrows),
							.result(result_shiftrows),
							.iready(iready_shiftrows),
							.oready(oready_shiftrows)
	);
	
	aes_mixcolumns mixcolumnsBlock (
							.clk(clk),
							.reset_n(reset_mixcolumns),
							.data(data_mixcolumns),
							.result(result_mixcolumns),
							.iready(iready_mixcolumns),
							.oready(oready_mixcolumns)	
	);
	
	aes_addroundkey addroundkeyBlock (
							.clk(clk),
							.reset_n(reset_addroundkey),
							.round_key(round_key),
							.data(data_addroundkey),
							.result(result_addroundkey),
							.iready(iready_addroundkey),
							.oready(oready_addroundkey)
	);
    
    // connections for the entire model	
	assign old_sbox 		= input_block; // data substitution when data coming  . 
	assign iready			= !tmp_iready;
	
	// connections among each function blocks
	assign reset_shiftrows 		= tmp_reset_shiftrows;
	assign reset_mixcolumns 	= oready_shiftrows;
	assign reset_addroundkey 	= oready_mixcolumns;
	assign oready 				= oready_addroundkey; 
	assign data_shiftrows		= input_buffer;
	assign data_mixcolumns		= result_shiftrows;
	assign data_addroundkey		= result_mixcolumns;
	assign output_block		    = result_addroundkey;

	initial 
	begin
		tmp_iready = 1'b0;
		tmp_reset_shiftrows = 1'b0;
	end 
	
	always @ (posedge clk)
	begin
		if (reset_n)
			begin
				input_buffer <= new_sbox;
				tmp_iready <= 1'b1;
				tmp_reset_shiftrows <= 1'b1;
			end
		else
			begin
				tmp_iready <= 1'b0;
				tmp_reset_shiftrows <= 1'b0;
			end
	end
endmodule