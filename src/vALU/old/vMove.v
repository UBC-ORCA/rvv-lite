module vMove #(
	parameter REQ_DATA_WIDTH  	= 64,
  	parameter REQ_ADDR_WIDTH 	= 32,
  	parameter REQ_BE_DATA_WIDTH = REQ_DATA_WIDTH/8,
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
	input 						     in_w_reg,
	input 							 in_sca,
	input 	 [REQ_BE_DATA_WIDTH-1:0] in_be,
  	output reg [ REQ_ADDR_WIDTH-1:0] out_addr,
	output reg [RESP_DATA_WIDTH-1:0] out_vec,
	output reg                       out_valid,
	output reg 						 out_w_reg,
	output reg 						 out_sca
);

	reg 						s0_valid, s1_valid, s2_valid, s3_valid, s4_valid;
	reg [RESP_DATA_WIDTH-1:0] 	s0_out_vec, s1_out_vec, s2_out_vec, s3_out_vec, s4_out_vec;
  	reg [ REQ_ADDR_WIDTH-1:0] 	s0_out_addr, s1_out_addr, s2_out_addr, s3_out_addr, s4_out_addr;
  	reg 						s0_w_reg, s1_w_reg, s2_w_reg, s3_w_reg, s4_w_reg;
  	reg 						s0_sca, s1_sca, s2_sca, s3_sca, s4_sca;

  	integer i;

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
            			
            s0_w_reg 	<= 'b0;
			s1_w_reg 	<= 'b0;
			s2_w_reg 	<= 'b0;
			s3_w_reg 	<= 'b0;
			s4_w_reg 	<= 'b0;
            out_w_reg  	<= 'b0;

            s0_sca	 	<= 'b0;
			s1_sca	 	<= 'b0;
			s2_sca	 	<= 'b0;
			s3_sca	 	<= 'b0;
			s4_sca	 	<= 'b0;
            out_sca	  	<= 'b0;
		end

		else begin
			s0_valid 	<= in_valid;
			s1_valid 	<= s0_valid;
			s2_valid 	<= s1_valid;
			s3_valid 	<= s2_valid;
			s4_valid 	<= s3_valid;
			out_valid  	<= s4_valid;

          	// for (i = 0; i < REQ_BE_DATA_WIDTH; i = i + 1) begin
          		// s0_out_vec[i*8 +: 8] 	<= in_valid & in_be[i] ? in_vec0[i*8 +: 8] : 'h0;
          	// end
          	s0_out_vec	<= in_valid ? in_vec0 : 'b0;
			s1_out_vec 	<= s0_out_vec;
			s2_out_vec 	<= s1_out_vec;
			s3_out_vec 	<= s2_out_vec;
			s4_out_vec 	<= s3_out_vec;
			out_vec 	<= s4_out_vec;
          
          	s0_out_addr <= in_valid ? in_addr : 'h0;
			s1_out_addr <= s0_out_addr;
			s2_out_addr <= s1_out_addr;
			s3_out_addr <= s2_out_addr;
			s4_out_addr <= s3_out_addr;
            out_addr  	<= s4_out_addr;

            s0_w_reg 	<= in_w_reg & in_valid;
			s1_w_reg 	<= s0_w_reg;
			s2_w_reg 	<= s1_w_reg;
			s3_w_reg 	<= s2_w_reg;
			s4_w_reg 	<= s3_w_reg;
			out_w_reg  	<= s4_w_reg;

			s0_sca 		<= in_sca & in_valid;
			s1_sca 		<= s0_sca;
			s2_sca 		<= s1_sca;
			s3_sca 		<= s2_sca;
			s4_sca 		<= s3_sca;
			out_sca  	<= s4_sca;
		end
	end

endmodule