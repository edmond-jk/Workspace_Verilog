module aes_invmixcolumns (
	input wire 				clk,
	input wire				reset_n,
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
  
  function [7:0] gm2(input [7:0] op);
  	begin
  		gm2 = {op[6:0], 1'b0} ^ (8'h1b & {8{op[7]}});
  	end
  endfunction
  
  function [7 : 0] gm3(input [7 : 0] op);
    begin
      gm3 = gm2(op) ^ op;
    end
  endfunction // gm3

  function [7 : 0] gm4(input [7 : 0] op);
    begin
      gm4 = gm2(gm2(op));
    end
  endfunction // gm4

  function [7 : 0] gm8(input [7 : 0] op);
    begin
      gm8 = gm2(gm4(op));
    end
  endfunction // gm8

  function [7 : 0] gm09(input [7 : 0] op);
    begin
      gm09 = gm8(op) ^ op;
    end
  endfunction // gm09

  function [7 : 0] gm11(input [7 : 0] op);
    begin
      gm11 = gm8(op) ^ gm2(op) ^ op;
    end
  endfunction // gm11

  function [7 : 0] gm13(input [7 : 0] op);
    begin
      gm13 = gm8(op) ^ gm4(op) ^ op;
    end
  endfunction // gm13
 
  function [7 : 0] gm14(input [7 : 0] op);
    begin
      gm14 = gm8(op) ^ gm4(op) ^ gm2(op);
    end
  endfunction // gm14 

  function [31 : 0] inv_mixw(input [31 : 0] w);
    reg [7 : 0] b0, b1, b2, b3;
    reg [7 : 0] mb0, mb1, mb2, mb3;
    begin
      b0 = w[31 : 24];
      b1 = w[23 : 16];
      b2 = w[15 : 08];
      b3 = w[07 : 00];

      mb0 = gm14(b0) ^ gm11(b1) ^ gm13(b2) ^ gm09(b3);
      mb1 = gm09(b0) ^ gm14(b1) ^ gm11(b2) ^ gm13(b3);
      mb2 = gm13(b0) ^ gm09(b1) ^ gm14(b2) ^ gm11(b3);
      mb3 = gm11(b0) ^ gm13(b1) ^ gm09(b2) ^ gm14(b3);

      inv_mixw = {mb0, mb1, mb2, mb3};
    end
  endfunction // mixw

  function [127 : 0] inv_mixcolumns(input [127 : 0] data);
    reg [31 : 0] w0, w1, w2, w3;
    reg [31 : 0] ws0, ws1, ws2, ws3;
    begin
      w0 = data[127 : 096];
      w1 = data[095 : 064];
      w2 = data[063 : 032];
      w3 = data[031 : 000];

      ws0 = inv_mixw(w0);
      ws1 = inv_mixw(w1);
      ws2 = inv_mixw(w2);
      ws3 = inv_mixw(w3);

      inv_mixcolumns = {ws0, ws1, ws2, ws3};
    end
  endfunction // inv_mixcolumns
  
  always @ (posedge clk)
  begin
  	if (reset_n)
  		begin
  			input_buffer = data;
  			tmp_iready = 1'b1;
  			
  			output_buffer = inv_mixcolumns(input_buffer);
  			tmp_oready = 1'b1;
  		end
  	else
  		begin
  			tmp_iready = 1'b0;
  			tmp_oready = 1'b0;
  		end
  end
endmodule