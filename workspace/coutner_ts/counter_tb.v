module counter_tb;
	reg clk, reset, enable;
	wire [3:0] count;
	reg dut_error; 
	counter U0 (.clk(clk), .reset(reset), .enable(enable), .count(count));

	event reset_enable;
	event terminate_sim;
		
	initial begin
		clk = 0;
		reset = 0;
		enable = 0;
		dut_error = 0;
	end
	
	always
		#5 clk = !clk;
		
	initial 
	@ (terminate_sim) begin
		$display ("Terminating simulation");
		if (dut_error == 0) begin
			$display ("Simulation Result: PASSED");
		end
		else begin
			$display("Simulatin Result: FAILED");
		end
		#1 $finish;
	end
	
	event reset_done;
	
	initial 
	forever begin
		@ (reset_enable);
		@ (negedge clk)
		$display("@ %d: Applying reset", $time);
		reset = 1;
	
		@ (negedge clk)
		reset = 0;	
		$display ("@ %d: Came out of Reset", $time);
		-> reset_done;
	end
	
	initial begin
		$display ("@ %d: event reset_enable", $time);
		#10 -> reset_enable;
		@ (reset_done);
		@ (negedge clk);
		enable = 1;
		$display ("@ %d: enable = 1", $time);
		repeat (5)
		begin 
			@ (negedge clk);
		end
		enable = 0;
		$display ("@ %d: enable = 0", $time);
			
		#5 -> terminate_sim;
	end
	
	reg [3:0] count_compare;
	always @ (posedge clk)
		if (reset == 1'b1) begin
			count_compare <= 0;
		end
		else if (enable == 1'b1) begin
			count_compare  <= count_compare + 1;
		end
		
	always @ (negedge clk)
		if (count_compare != count) begin
			$display ("@ %d: DUT error at time", $time);
			$display ("Expected value %d, Got value %d", count_compare, count);
			dut_error = 1;
			#5 -> terminate_sim;
		end
		
endmodule