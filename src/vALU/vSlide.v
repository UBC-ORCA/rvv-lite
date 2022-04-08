module vSlide #(
	parameter REQ_DATA_WIDTH    	= 64,
	parameter RESP_DATA_WIDTH   	= 64,
	parameter REQ_ADDR_WIDTH   		= 32,
	parameter SEW_WIDTH         	= 2 ,
	parameter REQ_BYTE_EN_WIDTH 	= 8
) (
	input                             	clk      ,
	input                              	rst      ,
	input      	[   REQ_DATA_WIDTH-1:0] in_vec0  ,
	input      	[   REQ_DATA_WIDTH-1:0] in_vec1  ,
	input                              	in_valid ,
	input      	[        SEW_WIDTH-1:0] in_sew   ,
	input                              	in_start ,
	input                              	in_end   ,
	input                              	in_opSel , //0-up,1-down
	input							   	in_insert,
	input		[   REQ_ADDR_WIDTH-1:0] in_addr  ,
	input    	[REQ_BYTE_EN_WIDTH-1:0] in_be    ,
	output reg	[REQ_BYTE_EN_WIDTH-1:0] out_be   ,
	output reg	[  RESP_DATA_WIDTH-1:0] out_vec  ,
	output reg                         	out_valid,
	output reg 	[   REQ_ADDR_WIDTH-1:0] out_addr
);

	reg [   REQ_DATA_WIDTH-1:0] s0_vec0, s0_vec1, s1_vec1;

	reg [   REQ_DATA_WIDTH-1:0] s2_up_remainder, s2_up_result, s3_up_result;
	reg [ REQ_DATA_WIDTH*2-1:0] s1_up_result   ;

	reg [   REQ_DATA_WIDTH-1:0] s2_down_result, s2_down_remainder, s1_down_remainder, s1_down_vec1_end,s2_down_vec1_end, s3_down_result, s4_result;
	reg [ REQ_DATA_WIDTH*2-1:0] s1_down_result;
	reg 						s0_insert; 

	reg [		 SEW_WIDTH-1:0]	s0_sew;
	reg                         s0_start, s1_start, s0_end, s1_end, s2_end;
	reg                         s0_opSel, s1_opSel, s2_opSel, s3_opSel;
	reg [REQ_BYTE_EN_WIDTH-1:0] s0_be, s1_be, s2_be, s3_be, s4_be;
	reg 						s0_valid, s1_valid, s2_valid, s3_valid, s4_valid;
	reg [ 	REQ_ADDR_WIDTH-1:0] s0_out_addr, s1_out_addr, s2_out_addr, s3_out_addr, s4_out_addr;


	wire [REQ_DATA_WIDTH*2-1:0] w_s0_up_vec0, w_s0_up_result, w_s0_down_vec0, w_s0_down_result;
	wire [  REQ_DATA_WIDTH-1:0] w_s1_up_remainder, w_s1_down_remainder, w_s1_down_vec1, w_s0_vec1, w_s0_be_shifted_right, w_s0_be_shifted_left;

	assign w_s0_vec1       			= s0_sew[1] ? (s0_sew[0] ? s0_vec1 : {2{s0_vec1[31:0]}}) : (s0_sew[0] ? {4{s0_vec1[15:0]}} : {8{s0_vec1[7:0]}});
	assign w_s0_be_shifted_right 	= s0_sew[1] ? (s0_sew[0] ? (s0_be >> 8) : (s0_be >> 4)) : (s0_sew[0] ? (s0_be >> 2) : (s0_be >> 1));
	assign w_s0_be_shifted_left 	= s0_sew[1] ? (s0_sew[0] ? (s0_be << 8) : (s0_be << 4)) : (s0_sew[0] ? (s0_be << 2) : (s0_be << 1));

	assign w_s0_down_vec0      		= {s0_vec0,64'b0};
	assign w_s1_down_remainder 		= s2_end ? s2_down_vec1_end : s1_down_remainder;
	assign w_s0_down_result    		= s0_sew[1] ? (s0_sew[0] ? (w_s0_down_vec0 >> 64) : (w_s0_down_vec0 >> 32)) : (s0_sew[0] ? (w_s0_down_vec0 >> 16) : (w_s0_down_vec0 >> 8));


	assign w_s1_up_remainder 		= s1_start ? s1_vec1 : s2_up_remainder;
	assign w_s0_up_vec0      		= {64'b0, s0_vec0};
	assign w_s0_up_result    		= s0_sew[1] ? (s0_sew[0] ? (w_s0_up_vec0 << 64) : (w_s0_up_vec0 << 32)) : (s0_sew[0] ? (w_s0_up_vec0 << 16) : (w_s0_up_vec0 << 8));

	always @(posedge clk) begin
		if(rst) begin
			s0_vec0          	<= 'b0;
			s0_vec1          	<= 'b0;
			s1_vec1          	<= 'b0;
			s1_down_vec1_end 	<= 'b0;
			s2_down_vec1_end 	<= 'b0;
			s1_up_result     	<= 'b0;
			s2_up_remainder  	<= 'b0;
			s2_up_result     	<= 'b0;
			s1_down_result    	<= 'b0;
			s1_down_remainder 	<= 'b0;
			s2_down_result    	<= 'b0;
			s3_down_result 		<= 'b0;
			s0_insert 			<= 'b0;
			s3_up_result 		<= 'b0;
			out_vec      		<= 'b0;

			s0_opSel     		<= 'b0;
			s1_opSel     		<= 'b0;
			s2_opSel     		<= 'b0;
			s3_opSel     		<= 'b0;

			s0_be  				<= 'b0;
			s1_be  				<= 'b0;
			s2_be  				<= 'b0;
			s3_be  				<= 'b0;
			s4_be  				<= 'b0;
			out_be 				<= 'b0;

			s0_sew    			<= 'b0;

			s0_valid  			<= 'b0;
			s1_valid  			<= 'b0;
			s2_valid  			<= 'b0;
			s3_valid  			<= 'b0;
			s4_valid  			<= 'b0;
			out_valid 			<= 'b0;

			s0_start  			<= 'b0;
			s1_start  			<= 'b0;
			s0_end    			<= 'b0;
			s1_end    			<= 'b0;
			s2_end 				<= 'b0;
			s4_result 			<= 'b0;

			s0_out_addr			<= 'b0;
			s1_out_addr			<= 'b0;
			s2_out_addr			<= 'b0;
			s3_out_addr			<= 'b0;
			s4_out_addr			<= 'b0;
			out_addr			<= 'b0;
		end
		else begin
			s0_vec0          	<= {REQ_DATA_WIDTH{in_valid}} & in_vec0;
			s0_vec1          	<= {REQ_DATA_WIDTH{in_valid}} & in_vec1;
			s1_vec1          	<= {REQ_DATA_WIDTH{in_valid}} & s0_vec1;
			s0_insert        	<= in_insert;
			s1_down_vec1_end 	<= w_s0_vec1 & (~{{8{w_s0_be_shifted_right[7]}},{8{w_s0_be_shifted_right[6]}},{8{w_s0_be_shifted_right[5]}},{8{w_s0_be_shifted_right[4]}},
									{8{w_s0_be_shifted_right[3]}},{8{w_s0_be_shifted_right[2]}},{8{w_s0_be_shifted_right[1]}},{8{w_s0_be_shifted_right[0]}}});
			s2_down_vec1_end 	<= s1_down_vec1_end;
			s1_up_result 		<= w_s0_up_result;
			s2_up_remainder 	<= s1_up_result[127:64];
			s2_up_result    	<= s1_up_result[63:0] | w_s1_up_remainder;
			s3_up_result    	<= s2_up_result;
			s0_sew 				<= {SEW_WIDTH{in_valid}} & in_sew;
			s1_down_remainder 	<= w_s0_down_result[63:0];
			s1_down_result    	<= w_s0_down_result[127:64];
			s2_down_result    	<= s1_down_result;
			s3_down_result    	<= s2_down_result | w_s1_down_remainder; //TODO: changed

			s4_result 			<= s3_opSel ? s3_down_result : s3_up_result;
			out_vec 			<= s4_result;

			s0_be  				<= {REQ_BYTE_EN_WIDTH{in_valid}} & in_be;
			s1_be  				<= ((~s0_insert) & s0_opSel & s0_end) ? (w_s0_be_shifted_right) : (((~s0_insert) & (~s0_opSel) & s0_start) ? (w_s0_be_shifted_left) : (s0_be)); 
			s2_be  				<= s1_be;
			s3_be  				<= s2_be;
			s4_be  				<= s3_be;
			out_be 				<= s4_be;

			s0_opSel 			<= in_valid & in_opSel;
			s1_opSel 			<= s0_opSel;
			s2_opSel 			<= s1_opSel;
			s3_opSel 			<= s2_opSel;

			s0_valid 			<= in_valid;
			s1_valid 			<= s0_valid;
			s2_valid 			<= s1_valid;
			s3_valid 			<= s2_valid;
			s4_valid 			<= s3_valid;
			out_valid 			<= s4_valid;

			s0_out_addr			<= {REQ_ADDR_WIDTH{in_valid}} & in_addr;
			s1_out_addr			<= s0_out_addr;
			s2_out_addr			<= s1_out_addr;
			s3_out_addr			<= s2_out_addr;
			s4_out_addr			<= s3_out_addr;
			out_addr 			<= s4_out_addr;

			s0_start 			<= in_valid & in_start;
			s1_start 			<= s0_start;
			s0_end 				<= in_valid & in_end;
			s1_end 				<= s0_end;
			s2_end 				<= s1_end;
		end
	end
endmodule