module tbm (
	clock,
	address_0,
//	address_1,
	data_0,
//	data_1,
	cs_0,
//	cs_1,
	we_0,
//	we_1,
);

parameter MEM_WIDTH = 256;
parameter ADDR_WIDTH = 32;
parameter RAM_DEPTH = 1024;

// input ports
input 						clock;
input 						cs_0;
//input 						cs_1;
input 						we_0;
//input 						we_1;
input [ADDR_WIDTH-1:0]		address_0;
//input [ADDR_WIDTH-1:0]		address_1;

// inout ports
inout [MEM_WIDTH-1:0]		data_0;
//inout [MEM_WIDTH-1:0]		data_1;

// internal variables
reg [MEM_WIDTH-1:0]			data_0_out;
//reg [MEM_WIDTH-1:0]			data_1_out;
reg [MEM_WIDTH-1:0]			Mem [0:RAM_DEPTH-1];

// code starts here
assign data_0 = (cs_0 && !we_0) ? data_0_out : 256'bz;
//assign data_1 = (cs_1 && !we_1) ? data_1_out : 256'bz;

always @ (posedge clock or negedge clock)
begin
	if (cs_0 && we_0) begin
		$display("W@%d : data:%d", $time, data_0);
		Mem[(address_0 >> 5)] <= data_0;
	end
end

always @ (posedge clock or negedge clock)
begin
	if (cs_0 && !we_0) begin
		data_0_out <= Mem[(address_0 >> 5)];
		$display("R@%d : data:%d", $time, data_0_out);
	end else begin
		data_0_out <= 0;
	end
end

endmodule
	
