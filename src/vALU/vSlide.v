module vSlide #(
	parameter REQ_DATA_WIDTH    	= 64,
	parameter RESP_DATA_WIDTH   	= 64,
	parameter REQ_ADDR_WIDTH   		= 32,
	parameter SEW_WIDTH         	= 3 ,
	parameter SHIFT_WIDTH 			= $clog2(REQ_DATA_WIDTH>>3),
	parameter REQ_BYTE_EN_WIDTH 	= 8 ,
	parameter ENABLE_64_BIT			= 1 ,
	parameter SLIDE_N_ENABLE 		= 1
) (
	input                             	clk      ,
	input                              	rst      ,
	input      	[   REQ_DATA_WIDTH-1:0] in_vec0  ,
	input      	[   REQ_DATA_WIDTH-1:0] in_vec1  ,
	input                              	in_valid ,
	input      	[      SHIFT_WIDTH-1:0] in_shift ,
	input                              	in_start ,
	input                              	in_end   ,
	input                              	in_opSel , //0-up,1-down
	input							   	in_insert,
	input		[   REQ_ADDR_WIDTH-1:0] in_addr  ,
	input    	[REQ_BYTE_EN_WIDTH-1:0] in_be    ,
	input 		[ 				  11:0] in_off 	 ,
	output reg	[REQ_BYTE_EN_WIDTH-1:0] out_be   ,
	output reg	[  RESP_DATA_WIDTH-1:0] out_vec  ,
	output reg                         	out_valid,
	output reg 	[   REQ_ADDR_WIDTH-1:0] out_addr ,
	output reg  [				  11:0] out_off
);

	reg [   REQ_DATA_WIDTH-1:0] s0_vec0, s0_vec1, s1_vec1;

	reg [   REQ_DATA_WIDTH-1:0] s2_up_remainder, s2_up_result, s3_up_result;
	reg [ REQ_DATA_WIDTH*2-1:0] s1_up_result   ;

	reg [   REQ_DATA_WIDTH-1:0] s2_down_result, s2_down_remainder, s1_down_remainder, s1_down_vec1_end,s2_down_vec1_end, s3_down_result, s4_result;
	reg [ REQ_DATA_WIDTH*2-1:0] s1_down_result;
	reg 						s0_insert; 

	reg [	   SHIFT_WIDTH-1:0] s0_shift;
	reg                         s0_start, s1_start, s0_end, s1_end, s2_end;
	reg                         s0_opSel, s1_opSel, s2_opSel, s3_opSel;
	reg [REQ_BYTE_EN_WIDTH-1:0] s0_be, s1_be, s2_be, s3_be, s4_be;
	reg 						s0_valid, s1_valid, s2_valid, s3_valid, s4_valid;
	reg [ 	REQ_ADDR_WIDTH-1:0] s0_out_addr, s1_out_addr, s2_out_addr, s3_out_addr, s4_out_addr;

	reg [				  11:0]	s0_out_off, s1_out_off, s2_out_off, s3_out_off, s4_out_off;

	wire [REQ_DATA_WIDTH*2-1:0] w_s0_up_vec0, w_s0_up_result, w_s0_down_vec0, w_s0_down_result, w_s0_up_result_n, w_s0_down_result_n;
	wire [  REQ_DATA_WIDTH-1:0] w_s1_up_remainder, w_s1_down_remainder, w_s0_be_shifted_right, w_s0_be_shifted_left;
	wire [  REQ_DATA_WIDTH-1:0] w_s0_be_r, w_s0_be_l, w_s0_vec1, w_s0_vec1_r, w_s0_vec1_l;

	// These do not change when slide_n is enabled


	if (SLIDE_N_ENABLE) begin
		assign w_s0_be_r 	= s0_be >> s0_shift;
		assign w_s0_be_l 	= s0_be << s0_shift;
	end else begin
		assign w_s0_be_r 	= s0_shift[0] ? s0_be >> 1 : (s0_shift[1] ? s0_be >> 2 : s0_be >> 4);
		assign w_s0_be_l 	= s0_shift[0] ? s0_be << 1 : (s0_shift[1] ? s0_be << 2 : s0_be << 4);
	end

	if (ENABLE_64_BIT & REQ_DATA_WIDTH >= 64) begin
		assign w_s0_vec1_r 	= s0_shift[0] ? {{(REQ_DATA_WIDTH-8){1'b0}},s0_vec1[7:0]} :
										(s0_shift[1] ? {{(REQ_DATA_WIDTH-16){1'b0}},s0_vec1[15:0]} :
														(s0_shift[2] ? {{(REQ_DATA_WIDTH-32){1'b0}},s0_vec1[31:0]} :
																		{{(REQ_DATA_WIDTH-64){1'b0}},s0_vec1[63:0]}));
		assign w_s0_vec1_l 	= s0_shift[0] ? {s0_vec1[7:0],{(REQ_DATA_WIDTH-8){1'b0}}} :
										(s0_shift[1] ? {s0_vec1[15:0],{(REQ_DATA_WIDTH-16){1'b0}}} :
														(s0_shift[2] ? {s0_vec1[31:0],{(REQ_DATA_WIDTH-32){1'b0}}} : 
																		{s0_vec1[63:0],{(REQ_DATA_WIDTH-64){1'b0}}}));
		assign w_s0_vec1       			= s0_insert ? (s0_opSel ? w_s0_vec1_l : w_s0_vec1_r) : 'h0;

		assign w_s0_be_shifted_right 	= (|s0_shift) ? w_s0_be_r : s0_be >> 8;
		assign w_s0_be_shifted_left 	= (|s0_shift) ? w_s0_be_l : s0_be << 8;
	end else begin
		assign w_s0_vec1_r 	= s0_shift[0] ? {{(REQ_DATA_WIDTH-8){1'b0}},s0_vec1[7:0]} :
										(s0_shift[1] ? {{(REQ_DATA_WIDTH-16){1'b0}},s0_vec1[15:0]} :
														{{(REQ_DATA_WIDTH-32){1'b0}},s0_vec1[31:0]});
		assign w_s0_vec1_l 	= s0_shift[0] ? {s0_vec1[7:0],{(REQ_DATA_WIDTH-8){1'b0}}} :
										(s0_shift[1] ? {s0_vec1[15:0],{(REQ_DATA_WIDTH-16){1'b0}}} :
														{s0_vec1[31:0],{(REQ_DATA_WIDTH-32){1'b0}}});
		assign w_s0_vec1       			= s0_insert ? (s0_opSel ? w_s0_vec1_l : w_s0_vec1_r) : 'h0;

		assign w_s0_be_shifted_right 	= w_s0_be_r;
		assign w_s0_be_shifted_left 	= w_s0_be_l;
	end

	assign w_s0_down_vec0      		= {s0_vec0,{(REQ_DATA_WIDTH){1'b0}}};
	assign w_s1_down_remainder 		= s2_end ? s2_down_vec1_end : s1_down_remainder;

	if (SLIDE_N_ENABLE) begin
		assign w_s0_down_result_n	= (w_s0_down_vec0 >> (s0_shift*8));
		assign w_s0_up_result_n 	= (w_s0_up_vec0 << (s0_shift*8));
	end else begin
		assign w_s0_down_result_n	= s0_shift[0] ? (w_s0_down_vec0 >> 8) : (s0_shift[1] ? (w_s0_down_vec0 >> 16) : (w_s0_down_vec0 >> 32));
		assign w_s0_up_result_n		= s0_shift[0] ? (w_s0_up_vec0 << 8) : (s0_shift[1] ? (w_s0_up_vec0 << 16) : (w_s0_up_vec0 << 32));
	end

	if (ENABLE_64_BIT) begin
		assign w_s0_down_result		= (|s0_shift) ? w_s0_down_result_n : (w_s0_down_vec0 >> 64);
	end else begin
		assign w_s0_down_result		= w_s0_down_result_n;
	end

	assign w_s1_up_remainder 		= s1_start ? w_s0_vec1 : s2_up_remainder;
	assign w_s0_up_vec0      		= {{(REQ_DATA_WIDTH){1'b0}}, s0_vec0};
	if (ENABLE_64_BIT & REQ_DATA_WIDTH >= 64) begin
		assign w_s0_up_result		= (|s0_shift) ? w_s0_up_result_n : (w_s0_up_vec0 << 64);
	end else begin
		assign w_s0_up_result		= w_s0_up_result_n;
	end

	always @(posedge clk) begin
		if(rst) begin
			s0_vec0          	<= 'b0;
			s0_vec1          	<= 'b0;

			s0_out_off			<= 'b0;
			s1_out_off			<= 'b0;
			s2_out_off			<= 'b0;
			s3_out_off			<= 'b0;
			s4_out_off			<= 'b0;

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

			s0_shift 			<= 'b0;

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
			s0_vec0          	<= in_valid ? in_vec0 : 'h0;
			s0_vec1          	<= in_valid ? in_vec1 : 'h0;

			s0_insert			<= in_valid & in_insert;

			s0_shift 			<= in_valid ? in_shift : 'h0;

			s1_down_vec1_end 	<= w_s0_vec1;
			s2_down_vec1_end 	<= s1_down_vec1_end;

			s1_up_result 		<= w_s0_up_result;
			s2_up_remainder 	<= s1_up_result[2*REQ_DATA_WIDTH-1:REQ_DATA_WIDTH];
			s2_up_result    	<= s1_up_result[REQ_DATA_WIDTH-1:0] | w_s1_up_remainder;
			s3_up_result    	<= s2_up_result;

			s1_down_remainder 	<= w_s0_down_result[REQ_DATA_WIDTH-1:0];
			s1_down_result    	<= w_s0_down_result[2*REQ_DATA_WIDTH-1:REQ_DATA_WIDTH];
			s2_down_result    	<= s1_down_result;
			s3_down_result    	<= s2_down_result | w_s1_down_remainder;

			s4_result 			<= s3_opSel ? s3_down_result : s3_up_result;
			out_vec 			<= s4_result;

			s0_be  				<= in_valid ? in_be : 'h0;
			s1_be  				<= (~s0_insert & s0_opSel & s0_end) ? (w_s0_be_shifted_right) : ((~s0_insert & ~s0_opSel & s0_start) ? (w_s0_be_shifted_left) : (s0_be));
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

			s0_out_addr			<= in_valid ? in_addr : 'h0;
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

			s0_out_off			<= in_valid & ~in_opSel ? in_off : 'h0;
			s1_out_off			<= s0_out_off;
			s2_out_off			<= s1_out_off;
			s3_out_off			<= s2_out_off;
			s4_out_off			<= s3_out_off;
			out_off 			<= s4_out_off;
		end
	end
endmodule