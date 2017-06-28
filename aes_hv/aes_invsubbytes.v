module aes_invsubbytes (
	input wire				clk,
	input wire				reset_n,
	input wire [127:0]		data,
	
	output wire [127:0]		old_sbox,
	input wire [127:0]		new_sbox,	
	
	output wire [127:0]		result,
	output wire				iready,
	output wire 			oready	
  );
  
  reg [127:0]		output_buffer;
  reg				tmp_iready, tmp_oready;
  
  assign iready = !tmp_iready;
  assign oready = tmp_oready;
  assign old_sbox = data;
  assign result = output_buffer;
  
  initial 
  begin
  	tmp_iready = 1'b0;
  	tmp_oready = 1'b0;
  end 
  
  always @ (posedge clk)
  begin
  	if (reset_n)
  		begin
  			tmp_iready = 1'b1;
  			tmp_oready = 1'b1;

  			output_buffer = new_sbox;
  			$display("INV_SUBBYTE: %X", output_buffer);
  		end
  	else
  		begin
  			tmp_iready = 1'b0;
  			tmp_oready = 1'b0;
  		end
  end
endmodule