// `include "vMinMaxSelector.v"
// `include "vAdd_unit_block.v"

module vAdd_min_max #(
	parameter REQ_DATA_WIDTH  = 64,
	parameter REQ_BYTE_EN_WIDTH = REQ_DATA_WIDTH/8,
	parameter RESP_DATA_WIDTH = 64,
	parameter REQ_ADDR_WIDTH  = 32,
	parameter SEW_WIDTH       = 2 ,
	parameter OPSEL_WIDTH     = 9 ,
	parameter MIN_MAX_ENABLE  = 1 ,
	parameter MASK_ENABLE	  = 1 ,
	parameter FXP_ENABLE      = 1
) (
	input                            	clk      ,
	input                            	rst      ,
	input      [   REQ_DATA_WIDTH-1:0] 	in_vec0  ,
	input      [   REQ_DATA_WIDTH-1:0] 	in_vec1  ,
	input                            	in_valid ,
	input      [        SEW_WIDTH-1:0] 	in_sew   ,
	input      [      OPSEL_WIDTH-1:0] 	in_opSel ,
	input                            	in_carry ,
	input	   [   REQ_ADDR_WIDTH-1:0] 	in_addr  ,
	input      [                  5:0] 	in_start_idx,
	input 								in_req_start,
	input 								in_req_end,
	input	   [REQ_BYTE_EN_WIDTH-1:0]	in_be,
	input 								in_avg,
	output reg [  RESP_DATA_WIDTH-1:0] 	out_vec  ,
	output reg                       	out_valid,
	output reg [   REQ_ADDR_WIDTH-1:0] 	out_addr ,
	output reg [REQ_BYTE_EN_WIDTH-1:0]	out_be,
	output reg 						 	out_mask,
	output reg [REQ_BYTE_EN_WIDTH-1:0]	out_vd,
	output reg [REQ_BYTE_EN_WIDTH-1:0] 	out_vd1,
	output reg 							out_fxp
);

	genvar i;

	reg [ REQ_DATA_WIDTH-1:0] s0_vec0, s1_vec0;
	reg [ REQ_DATA_WIDTH-1:0] s0_vec1, s1_vec1;
	reg [RESP_DATA_WIDTH-1:0] s1_out_vec, s2_out_vec, s3_out_vec, s4_out_vec;
	reg [      SEW_WIDTH-1:0] s0_sew, s1_sew, s2_sew;
	reg [    OPSEL_WIDTH-1:0] s0_opSel, s1_opSel;
	reg                       s0_valid, s1_valid, s2_valid, s3_valid, s4_valid;
	reg [                7:0] s1_gt, s1_lt, s1_equal;
	reg 					  s2_mask, s3_mask, s4_mask;
	reg [    		     5:0] s0_start_idx, s1_start_idx, s2_start_idx;
	reg 					  s0_req_end, s1_req_end, s2_req_end, s3_req_end;
	reg 					  s0_req_start, s1_req_start, s2_req_start;
	reg [REQ_BYTE_EN_WIDTH-1:0] s0_out_be, s1_out_be, s2_out_be, s3_out_be, s4_out_be;

	reg [ REQ_ADDR_WIDTH-1:0] s0_out_addr, s1_out_addr, s2_out_addr, s3_out_addr, s4_out_addr;

	reg [REQ_BYTE_EN_WIDTH-1:0] s4_vd;
	reg [REQ_BYTE_EN_WIDTH-1:0] s4_vd1;
	reg 					  s0_avg, s1_avg, s2_avg, s3_avg, s4_avg;

	wire [REQ_DATA_WIDTH+16:0] s1_result;

	wire [RESP_DATA_WIDTH-1:0] w_minMax_result  ;
	wire [RESP_DATA_WIDTH-1:0] w_s1_arith_result;
	wire [                7:0] w_gt, w_lt, w_equal;

	wire [RESP_DATA_WIDTH-1:0] avg_vec_out;
	wire [REQ_BYTE_EN_WIDTH-1:0] avg_vd, avg_vd1;

	generate
		if(MIN_MAX_ENABLE | MASK_ENABLE) begin : min_max_mask
			vMinMaxSelector vMinMaxSelector0 (
				.vec0(s0_vec0),
				.vec1(s0_vec1),
				.sub_result(s1_result),
				.sew(s0_sew),
				.minMax_sel(s0_opSel[3]),
				.minMax_result(w_minMax_result),
				.equal(w_equal),
				.lt(w_lt)
			);
		end else begin
			assign w_minMax_result 	= 0;
			assign w_equal 			= 0;
			assign w_lt 			= 0;
		end
	endgenerate

	assign w_s1_arith_result = {s1_result[78:71],s1_result[68:61],s1_result[58:51],s1_result[48:41],s1_result[38:31],s1_result[28:21],s1_result[18:11],s1_result[8:1]};

	vAdd_unit_block vAdd_unit0 (
		.clk   (clk      ),
		.rst   (rst      ),
		.vec0  (s0_vec0  ),
		.vec1  (s0_vec1  ),
		.carry (1'b0	 ),
		.sew   (s0_sew   ),
		.opSel (s0_opSel ),
		.result(s1_result)
	);

	generate
		if (FXP_ENABLE) begin : fxp
			avg_unit #(.DATA_WIDTH(REQ_DATA_WIDTH)) fxp_avg (
				.clk   	(clk		),
				.vec_in	(s2_out_vec	),
				.sew   	(s2_sew		),
				.v_d 	(avg_vd		),
				.v_d1  	(avg_vd1	),
				.vec_out(avg_vec_out)
			);
		end else begin
			assign avg_vd = 'h0;
			assign avg_vd1 = 'h0;
			assign avg_vec_out = 'h0;
		end
	endgenerate

	always @(posedge clk) begin
		if(rst) begin
			s0_vec0    	<= 'b0;
			s1_vec0    	<= 'b0;
			s0_vec1    	<= 'b0;
			s1_vec1    	<= 'b0;
			s1_out_vec 	<= 'b0;
			s2_out_vec 	<= 'b0;
			s3_out_vec 	<= 'b0;
			s4_out_vec	<= 'b0;
			out_vec    	<= 'b0;

			s0_sew     	<= 'b0;
			s1_sew     	<= 'b0;

			s0_opSel   	<= 'b0;
			s1_opSel   	<= 'b0;
			s1_opSel   	<= 'b0;

			s0_valid   	<= 'b0;
			s1_valid   	<= 'b0;
			s1_valid   	<= 'b0;
			s2_valid   	<= 'b0;
			s3_valid   	<= 'b0;
			s4_valid 	<= 'b0;
			out_valid  	<= 'b0;

			s1_equal   	<= 'b0;
			s1_gt      	<= 'b0;
			s1_lt      	<= 'b0;

			s0_out_addr	<= 'b0;
			s1_out_addr	<= 'b0;
			s1_out_addr	<= 'b0;
			s2_out_addr	<= 'b0;
			s3_out_addr	<= 'b0;
			s4_out_addr <= 'b0;
			out_addr   	<= 'b0;
		end
		else begin
			s0_vec0  	<= in_valid ? in_vec0 		: 'h0;//{REQ_DATA_WIDTH{in_valid}} & in_vec0;
			s0_vec1  	<= in_valid ? in_vec1 		: 'h0;//{REQ_DATA_WIDTH{in_valid}} & in_vec1;
			s0_sew   	<= in_valid ? in_sew  		: 'h0;//{SEW_WIDTH{in_valid}} & in_sew;
			s0_valid 	<= in_valid;
			s0_opSel 	<= in_valid ? in_opSel 		: 'h0; //{OPSEL_WIDTH{in_valid}} & in_opSel;
			s0_out_addr	<= in_valid ? in_addr  		: 'h0; //{REQ_ADDR_WIDTH{in_valid}} & in_addr;
			s0_start_idx<= in_valid ? in_start_idx 	: 'h0;
			s0_req_end	<= in_valid ? in_req_end 	: 'h0;
			s0_req_start<= in_valid ? in_req_start 	: 'h0;
			s0_out_be   <= in_valid ? in_be			: 'h0;
			s0_avg		<= in_valid ? in_avg		: 'h0;

			s1_vec0  	<= s0_vec0;
			s1_vec1  	<= s0_vec1;
			s1_sew   	<= s0_sew;
			s1_opSel 	<= s0_opSel;
			s1_valid   	<= s0_valid;
			s1_out_addr	<= s0_out_addr;
			s1_start_idx<= s0_start_idx;
			s1_req_end	<= s0_req_end;
			s1_req_start<= s0_req_start;
			s1_out_be 	<= s0_out_be;
			s1_avg 		<= s0_avg;

			if (MIN_MAX_ENABLE | MASK_ENABLE) begin
				s1_out_vec 	<=	s1_opSel[4] ? w_minMax_result : w_s1_arith_result;
			end else begin
				s1_out_vec 	<=	w_s1_arith_result;
			end
			s1_equal   	<= w_equal;
			s1_gt      	<= w_gt;
			s1_lt      	<= w_lt;

			s2_valid   	<= s1_valid;
			s2_out_addr	<= s1_out_addr;

			if (MASK_ENABLE) begin
				case(s1_opSel[8:5])
					4'b1000 : s2_out_vec 	<= s1_equal;
					4'b1001 : s2_out_vec 	<= ~s1_equal;
					4'b1010,
					4'b1011 : s2_out_vec 	<= s1_lt;
					4'b1100,
					4'b1101 : s2_out_vec 	<= s1_equal | s1_lt;
					4'b1110,
					4'b1111 : s2_out_vec 	<= ~(s1_equal | s1_lt);
					default : s2_out_vec 	<= s1_out_vec;
				endcase
			end else begin
				s2_out_vec 	<= s1_out_vec;
			end
			s2_start_idx<= s1_start_idx;
			s2_req_end	<= s1_req_end;
			s2_req_start<= s1_req_start;
			s2_out_be 	<= s1_out_be;
			s2_avg 		<= s1_avg;
			s2_sew 		<= s1_sew;

			if (MASK_ENABLE) begin
				s3_out_vec 	<= ~s2_mask ? s2_out_vec : ((s2_start_idx[2:0] == 0 | s2_req_end) ? (s2_out_vec << s2_start_idx) : ((s2_out_vec << s2_start_idx) | s3_out_vec));
				s3_valid   	<= s2_valid & (~s2_mask | (s1_start_idx[2:0] == 0) | s2_req_end);
	         	s3_out_addr <= s2_out_addr;
	         	s3_out_be 	<= ~s2_mask ? s2_out_be : (s2_req_start ? 'h1 : ((s2_start_idx[2:0] == 0 | s3_req_end) ? {s3_out_be[REQ_BYTE_EN_WIDTH-2:0],s3_out_be[REQ_BYTE_EN_WIDTH-1]} : s3_out_be));
	         	s3_mask 	<= s2_mask;
	         end else begin
	         	s3_out_vec 	<= s2_out_vec;
				s3_valid   	<= s2_valid;
	         	s3_out_addr <= s2_out_addr;
	         	s3_out_be 	<= s2_out_be;
	         	s3_mask 	<= 0;
	        end
         	s3_avg 		<= s2_avg;

         	s4_out_vec 	<= s3_avg ? avg_vec_out : s3_out_vec;
         	s4_vd 		<= s3_avg ? avg_vd : 'h0;
         	s4_vd1 		<= s3_avg ? avg_vd1 : 'h0;
			s4_valid   	<= s3_valid;
         	s4_out_addr <= s3_out_addr;
         	s4_out_be 	<= s3_valid ? s3_out_be : 'h0;
         	s4_mask 	<= s3_mask;
         	s4_avg 		<= s3_avg;

			out_vec   	<= s4_out_vec;
			out_valid 	<= s4_valid;
			out_addr  	<= s4_out_addr;
			out_be 		<= s4_out_be;
			out_mask 	<= s4_mask;
			out_fxp		<= s4_avg;
			out_vd 		<= s4_vd;
			out_vd1 	<= s4_vd1;
		end
	end

	generate
		if (MASK_ENABLE) begin
			always @(posedge clk) begin
				s2_mask <= s1_opSel[8];
			end
		end else begin
			always @(*) begin
				s2_mask	= 1'b0;
			end
		end
	endgenerate

endmodule

module avg_unit #(
	parameter DATA_WIDTH 	= 64,
	parameter DW_B 			= DATA_WIDTH>>3
) (
	input 						clk,
	input  	   [DATA_WIDTH-1:0] vec_in,
	input  	   [		   1:0] sew,
	output reg [	  DW_B-1:0] v_d,
	output reg [	  DW_B-1:0] v_d1, // v_d and v_d10 are the same for this op
	output reg [DATA_WIDTH-1:0] vec_out
);

reg  [DATA_WIDTH-1:0] vec_out_sew 	[0:3];
reg  [		DW_B-1:0] v_d_sew		[0:3];
reg  [		DW_B-1:0] v_d1_sew		[0:3];

genvar i;
integer j;
generate
	for (i = 0; i < 4; i = i + 1) begin
		always @(*) begin
			for (j = 0; j < DW_B >> i; j = j + 1) begin
				vec_out_sew	[i][(j<<(i+3)) +: (1<<(i+3))] = vec_in[(j<<(i+3)) + 1 +: ((1 << (i+3)) - 1)];

				v_d_sew 	[i][j<<i] = vec_in[(j<<(i+3)) + 1];
				v_d1_sew	[i][j<<i] = vec_in[j<<(i+3)];
			end
		end
	end

	always @(posedge clk) begin
		vec_out <=	vec_out_sew[sew];

		v_d 	<=	v_d_sew [sew];
		v_d1 	<=	v_d1_sew[sew];
	end
endgenerate

endmodule