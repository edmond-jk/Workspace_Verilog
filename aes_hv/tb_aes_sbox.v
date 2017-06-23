module tb_aes_sbox();

reg [31:0] 	in_block[0:9];
wire [31:0]	out_block[0:9];



aes_sbox dut (
	.in_block_0(in_block[0]),
	.in_block_1(in_block[1]),
	.in_block_2(in_block[2]),
	.in_block_3(in_block[3]),
	.in_block_4(in_block[4]),
	.in_block_5(in_block[5]),
	.in_block_6(in_block[6]),
	.in_block_7(in_block[7]),
	.in_block_8(in_block[8]),
	.in_block_9(in_block[9]),
	.out_block_0(out_block[0]),
	.out_block_1(out_block[1]),
	.out_block_2(out_block[2]),
	.out_block_3(out_block[3]),
	.out_block_4(out_block[4]),
	.out_block_5(out_block[5]),
	.out_block_6(out_block[6]),
	.out_block_7(out_block[7]),
	.out_block_8(out_block[8]),
	.out_block_9(out_block[9])
	);
	
initial 
begin
	in_block[0] = 32'h19a0_9ae9;
	in_block[1] = 32'h19a0_9ae9;
//	#1;
	$display ("out_block[0]: 0x%X", out_block[0]);
	$display ("out_block[1]: 0x%X", out_block[1]);
end
	
endmodule