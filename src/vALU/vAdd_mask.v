module vAdd_mask #(
	parameter REQ_DATA_WIDTH  	= 64,
	parameter RESP_DATA_WIDTH 	= 64,
	parameter SEW_WIDTH       	= 2,
	parameter OPSEL_WIDTH     	= 3,
	parameter MIN_MAX_ENABLE  	= 1
) (
	input                          	clk,
	input                          	rst,
	input   [ REQ_DATA_WIDTH/8-1:0] in_m0,
	input                          	in_valid,
	input   [	     SEW_WIDTH-1:0] in_sew,
	input 	[	REQ_DATA_WIDTH-1:0]	in_count,
	output 	[  RESP_DATA_WIDTH-1:0] out_vec
	);

	reg [ 				 1:0]	s0_add0, s0_add1, s0_add2, s0_add3;
	reg [ 				 2:0] 	s1_add0, s1_add1;
	reg [ 				 3:0] 	s2_add0;
	reg [RESP_DATA_WIDTH-1:0] 	s0_count, s1_count, s2_count;

	assign out_vec = s2_add0 + s2_count;

	always @(posedge clk) begin
		if(rst) begin
			s0_add0 <= 'b0;
			s0_add1 <= 'b0;
			s0_add2 <= 'b0;
			s0_add3 <= 'b0;

			s1_add0 <= 'b0;
			s1_add1 <= 'b0;

			s2_add0 <= 'b0;

			s0_count <= 'b0;
			s1_count <= 'b0;
			s2_count <= 'b0;
		end

		else begin
            s0_add0 	<= {2{in_valid}} & (in_m0[0] + in_m0[1]);
            s0_add1 	<= {2{in_valid}} & (in_m0[2] + in_m0[3]);
            s0_add2 	<= {2{in_valid}} & (in_m0[4] + in_m0[5]);
            s0_add3 	<= {2{in_valid}} & (in_m0[6] + in_m0[7]);

            s0_count 	<= 'b0;//{RESP_DATA_WIDTH{in_valid}} & in_count;

            s1_add0 	<= s0_add0 + s0_add1;
            s1_add1 	<= s0_add2 + s0_add3;
            s1_count 	<= s0_count;
            s2_add0 	<= s1_add0 + s1_add1;
            s2_count 	<= s1_count;
		end
	end

endmodule