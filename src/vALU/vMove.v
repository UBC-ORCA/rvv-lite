module vMove #(
	parameter REQ_DATA_WIDTH  	= 64,
  	parameter REQ_ADDR_WIDTH 	= 32,
	parameter RESP_DATA_WIDTH 	= 64,
	parameter SEW_WIDTH       	= 2,
	parameter OPSEL_WIDTH     	= 3,
	parameter MIN_MAX_ENABLE  	= 1
) (
	input                            clk,
	input                            rst,
  	input 		[REQ_ADDR_WIDTH-1:0] in_addr,
	input      	[REQ_DATA_WIDTH-1:0] in_vec0,
	input                            in_valid,
  	output reg [ REQ_ADDR_WIDTH-1:0] out_addr,
	output reg [RESP_DATA_WIDTH-1:0] out_vec,
	output reg                       out_valid
);

	reg 						s0_valid, s1_valid, s2_valid, s3_valid, s4_valid;
	reg [RESP_DATA_WIDTH-1:0] 	s0_out_vec, s1_out_vec, s2_out_vec, s3_out_vec, s4_out_vec;
  	reg [ REQ_ADDR_WIDTH-1:0] 	s0_out_addr, s1_out_addr, s2_out_addr, s3_out_addr, s4_out_addr;

	always @(posedge clk) begin
		if(rst) begin
          	s0_out_addr <= 'b0;
			s1_out_addr <= 'b0;
			s2_out_addr <= 'b0;
			s3_out_addr <= 'b0;
			s4_out_addr <= 'b0;
            out_addr  	<= 'b0;
          
			s0_out_vec 	<= 'b0;
			s1_out_vec 	<= 'b0;
			s2_out_vec 	<= 'b0;
			s3_out_vec 	<= 'b0;
			s4_out_vec 	<= 'b0;
			out_vec    	<= 'b0;
			
			s0_valid 	<= 'b0;
			s1_valid 	<= 'b0;
			s2_valid 	<= 'b0;
			s3_valid 	<= 'b0;
			s4_valid 	<= 'b0;
            out_valid  	<= 'b0;
		end

		else begin
			s0_valid 	<= in_valid;
			s1_valid 	<= s0_valid;
// 			s2_valid 	<= s1_valid;
// 			s3_valid 	<= s2_valid;
			s4_valid 	<= s1_valid;
			out_valid  	<= s4_valid;
          
          	s0_out_vec 	<= {RESP_DATA_WIDTH{in_valid}} & in_vec0;
			s1_out_vec 	<= s0_out_vec;
// 			s2_out_vec 	<= s1_out_vec;
// 			s3_out_vec 	<= s2_out_vec;
			s4_out_vec 	<= s1_out_vec;
			out_vec 	<= s4_out_vec;
          
          	s0_out_addr <= {REQ_ADDR_WIDTH{in_valid}} & in_addr;
			s1_out_addr <= s0_out_addr;
// 			s2_out_addr <= s1_out_addr;
// 			s3_out_addr <= s2_out_addr;
			s4_out_addr <= s1_out_addr;
            out_addr  	<= s4_out_addr;
		end
	end

endmodule