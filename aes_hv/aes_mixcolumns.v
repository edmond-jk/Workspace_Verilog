module aes_mixcolumns (
	input wire				clk,
	input wire				reset_n,
	input wire [127:0]		data,
	output wire [127:0]		result,
	output wire				iready,
	output wire				oready
	);
  
  reg				tmp_iready, tmp_oready;
  reg [127:0]		input_buffer, output_buffer;
  
  assign iready = !tmp_iready;
  assign oready = tmp_oready;
  assign result = output_buffer;
  
  initial 
  begin
  	tmp_iready = 1'b0;
  	tmp_oready = 1'b0;
  end
  
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
	
	always @ (posedge clk)
	begin
		if (reset_n)
			begin
				input_buffer = data;
				tmp_iready = 1'b1;
				output_buffer = mixcolumns(input_buffer);
				tmp_oready = 1'b1;
			end
		else
			begin
				tmp_iready = 1'b0;
				tmp_oready = 1'b0;
			end
	end
endmodule	