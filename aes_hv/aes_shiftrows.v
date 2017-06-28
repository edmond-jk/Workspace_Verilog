module aes_shiftrows(
	input wire 				clk, 
	input wire 				reset_n,
	input wire [127:0]		data,
	output wire [127:0]		result,
	output wire				iready,
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
  
   always @ (posedge clk)
   begin
   	if (reset_n)
   		begin
   			input_buffer = data;
   			tmp_iready = 1'b1;
   			
   			output_buffer = shiftRows(input_buffer);
   			tmp_oready = 1'b1;
   		end
   	else
   		begin
   			tmp_iready = 1'b0;
   			tmp_oready = 1'b0;
   		end
   end 
endmodule