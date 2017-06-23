`include "hd_parameter.vh"

module storageQ (
	reset,
	clock_fpga,
	sq_select,
	cmd_in,
	status_update_enable,
	cmdq_index
);

// ports
input 							reset;
input 							clock_fpga;
input 							sq_select;
input [`CMD_DATA_WIDTH - 1:0]	cmd_in;
output 							status_update_enable;
output [7:0]					cmdq_index;

// data types for ports
reg [7:0]						cmdq_index;
reg [7:0]						storageQ[`MAX_CMDQ_DEPTH-1:0][31:0]; // 1Byte x 32 (queue depth) x 32		
reg [7:0]						head, tail, current;
// reset all parameters
always @ (posedge clock_fpga)
begin
	if (reset) begin
		head 	= 8'h00;
		tail 	= 8'h00;
		current = 8'h00;
	end
end
endmodule
