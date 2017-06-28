module aes_addroundkey(
	input wire				clk,
	input wire				reset_n,
	input wire [127:0]		round_key,
	input wire [127:0]		data,
	output wire [127:0]		result,
	output wire 			iready,
	output wire				oready	
  );
  
  reg [127:0]		input_buffer, output_buffer;
  reg				tmp_iready, tmp_oready;
  
  assign iready = !tmp_iready;
  assign oready = tmp_oready;
  assign result = output_buffer;
  
  initial 
  begin
  	tmp_iready = 1'b0;
  	tmp_oready = 1'b0; 
  end
  
  function [127:0]  addroundkey(input [127:0] data, input [127:0] rkey);
		begin
			addroundkey = data ^ rkey;
		end
  endfunction 
  
  always @ (posedge clk)
  begin
  	if (reset_n)
  		begin
  			input_buffer = data;
  			tmp_iready = 1'b1;
  			
  			output_buffer = addroundkey (input_buffer, round_key);
  			tmp_oready = 1'b1;
  		end
  	else
  		begin
  			tmp_iready = 1'b0;
  			tmp_oready = 1'b0;
  		end
  end	
endmodule