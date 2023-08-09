/*
`include "vAdd_mask.v"
*/

module vPopc #(
	parameter REQ_DATA_WIDTH  	= 64,
	parameter RESP_DATA_WIDTH 	= 64,
	parameter REQ_ADDR_WIDTH 	= 32
) (
	input                            	clk,
	input                            	rst,
	input		[   REQ_DATA_WIDTH-1:0] in_m0,
	input                            	in_valid,
	input 							 	in_end,
	input 		[   REQ_ADDR_WIDTH-1:0] in_addr,
	output reg 	[  RESP_DATA_WIDTH-1:0] out_vec,
	output reg 	[   REQ_ADDR_WIDTH-1:0] out_addr,
	output reg						 	out_valid
	);

	reg 	[  RESP_DATA_WIDTH-1:0] count;
	wire 	[  RESP_DATA_WIDTH-1:0] w_count;
	wire 	[  RESP_DATA_WIDTH-1:0] w_s1_mask;
	
 	reg 	[  RESP_DATA_WIDTH-1:0] s0_mask;
 	reg 							s0_valid;
	reg 							s0_end, s1_end, s2_end, s3_end, s4_end;
	reg 	[   REQ_ADDR_WIDTH-1:0] s0_out_addr, s1_out_addr, s2_out_addr, s3_out_addr, s4_out_addr;

	vAdd_mask vAdd_mask0 (
		.clk   		(clk      	),
		.rst   		(rst      	),
		.in_valid 	(s0_valid	),
		.in_m0  	(s0_mask  	),
		.in_count	(w_count 	),
		.out_vec	(w_count	)
	);

	always @(posedge clk) begin
		if(rst) begin
			s0_mask 	<= 'b0;
			s0_valid 	<= 'b0;

			count 		<= 'b0;
			out_vec 	<= 'b0;
			
			s0_end 		<= 'b0;
			s1_end 		<= 'b0;
			s2_end 		<= 'b0;
			s3_end 		<= 'b0;
			s4_end 		<= 'b0;
			out_valid 	<= 'b0;

			s0_out_addr	<= 'b0;
			s1_out_addr	<= 'b0;
			s2_out_addr	<= 'b0;
			s3_out_addr	<= 'b0;
			s4_out_addr	<= 'b0;
			out_addr 	<= 'b0;
		end

		else begin
			s0_mask 	<= in_valid ? in_m0 : 'h0;
			s0_valid 	<= in_valid | s0_end | s1_end | s2_end | s3_end; // :/

			count 		<= s4_end ? 'b0 : w_count;
			out_vec 	<= s4_end ? count : 'b0;

			s0_end 		<= in_end & in_valid;
			s1_end 		<= s0_end;
			s2_end 		<= s1_end;
			s3_end 		<= s2_end;
			s4_end 		<= s3_end;
			out_valid 	<= s4_end;

			s0_out_addr <= in_valid ? in_addr : 'h0;
			s1_out_addr	<= s0_out_addr;
			s2_out_addr	<= s1_out_addr;
			s3_out_addr	<= s2_out_addr;
			s4_out_addr	<= s3_out_addr;
			out_addr 	<= s4_out_addr;
		end
	end

endmodule