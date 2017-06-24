module tbm_tb();
	parameter phase_nothing = 0;
	parameter phase_writing = 1;
	parameter phase_reading = 2;
	
	reg clock;
	reg [31:0] address_0;
	reg cs_0, we_0; 
	wire [255:0] data_0;
	
	reg [255:0] data_0_out;
	reg			data_0_oe;
	reg [1:0]	io_phase;

	assign data_0 = (data_0_oe)? data_0_out:256'bz;
//	assign data_1 = (data_1_oe)? data_1_out:256'bz;
	
	initial 
	begin
		clock = 1'b1;
		io_phase = phase_nothing;
	end
	
	always #5 clock = ~clock;
		
	initial 
	forever begin
		// write
		@ (posedge clock or negedge clock)
		if (io_phase == phase_nothing)
			io_phase = phase_writing;
		else if (io_phase == phase_writing) 
		begin
			cs_0 = 1'b1;
			we_0 = 1'b1;
			address_0 = 0;
			data_0_out = 256'hFFFF;
			data_0_oe = 1;
			io_phase = phase_reading;
			
		end else if (io_phase == phase_reading) begin
			cs_0 = 1'b1;
			we_0 = 1'b0;
			address_0 = 0;
			
			$display("@%d: data: %h", $time, data_0);
		end
		
	end
	
	tbm U1 (
		.clock(clock),
		.cs_0(cs_0),
	//	.cs_1(cs_1),
		.we_0(we_0),
	//	.we_1(we_1),
		.data_0(data_0),
	//	.data_1(data_1),
		.address_0(address_0)
	//	.address_1(address_1)
	);
endmodule 