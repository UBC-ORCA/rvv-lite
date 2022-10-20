// `include "vMinMaxSelector.v"
// `include "vAdd_unit_block.v"
`include "avg_unit.sv"

`define MIN(a,b) {(a > b) ? b : a}

module vAdd_min_max #(
	parameter REQ_DATA_WIDTH  = 64,
	parameter REQ_BYTE_EN_WIDTH = REQ_DATA_WIDTH/8,
	parameter RESP_DATA_WIDTH = 64,
	parameter REQ_ADDR_WIDTH  = 32,
	parameter SEW_WIDTH       = 2 ,
	parameter OPSEL_WIDTH     = 9 ,
	parameter MIN_MAX_ENABLE  = 1 ,
	parameter MASK_ENABLE	  = 1 ,
	parameter MASK_ENABLE_EXT = 1 ,
	parameter FXP_ENABLE      = 1 ,
	parameter ENABLE_64_BIT	  = 0
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
	input 								in_mask,
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

	reg [	REQ_DATA_WIDTH-1:0] s0_vec0, s1_vec0;
	reg [	REQ_DATA_WIDTH-1:0] s0_vec1, s1_vec1;
	reg [	REQ_DATA_WIDTH-1:0] s0_carry_in;
	reg 						s0_carry_res, s1_carry_res, s2_carry_res;
	reg [  RESP_DATA_WIDTH-1:0] s1_out_vec, s2_out_vec, s3_out_vec, s4_out_vec;
	reg [    	 SEW_WIDTH-1:0] s0_sew, s1_sew, s2_sew;
	reg [      OPSEL_WIDTH-1:0] s0_opSel, s1_opSel;
	reg                       	s0_valid, s1_valid, s2_valid, s3_valid, s4_valid;
	reg [                  7:0] s1_gt, s1_lt, s1_equal;
	reg 					  	s2_mask, s3_mask, s4_mask;
	reg [    		       5:0] s0_start_idx, s1_start_idx, s2_start_idx;
	reg 					  	s0_req_end, s1_req_end, s2_req_end, s3_req_end;
	reg 					  	s0_req_start, s1_req_start, s2_req_start;
	reg [REQ_BYTE_EN_WIDTH-1:0] s0_out_be, s1_out_be, s2_out_be, s3_out_be, s4_out_be;

	reg [	REQ_ADDR_WIDTH-1:0] s0_out_addr, s1_out_addr, s2_out_addr, s3_out_addr, s4_out_addr;

	reg [REQ_BYTE_EN_WIDTH-1:0] s4_vd;
	reg [REQ_BYTE_EN_WIDTH-1:0] s4_vd1;
	reg 					  	s0_avg, s1_avg, s2_avg, s3_avg, s4_avg;

	wire [ REQ_DATA_WIDTH+16:0] s1_result;

	wire [ RESP_DATA_WIDTH-1:0] w_minMax_result  ;
	wire [ RESP_DATA_WIDTH-1:0] w_s1_arith_result;
	reg  [ RESP_DATA_WIDTH-1:0] w_s1_carry_result;
	wire [                 7:0] w_gt, w_lt, w_equal;

	wire [  RESP_DATA_WIDTH-1:0] avg_vec_out;
	wire [REQ_BYTE_EN_WIDTH-1:0] avg_vd, avg_vd1;

	generate
		if(MIN_MAX_ENABLE | MASK_ENABLE) begin : min_max_mask
			vMinMaxSelector #(
				.REQ_DATA_WIDTH(REQ_DATA_WIDTH),
				.RESP_DATA_WIDTH(RESP_DATA_WIDTH),
				.SEW_WIDTH(SEW_WIDTH),
				.ENABLE_64_BIT(ENABLE_64_BIT)
			) vMinMaxSelector0 (
				.vec0			(s0_vec0		),
				.vec1			(s0_vec1		),
				.sub_result		(s1_result 		),
				.sew 			(s0_sew			),
				.minMax_sel 	(s0_opSel[3]	),
				.minMax_result 	(w_minMax_result),
				.equal 			(w_equal 		),
				.lt 			(w_lt 			)
			);
		end else begin
			assign w_minMax_result 	= 'h0;
			assign w_equal 			= 'h0;
			assign w_lt 			= 'h0;
		end
	endgenerate

	assign w_s1_arith_result = {s1_result[78:71],s1_result[68:61],s1_result[58:51],s1_result[48:41],s1_result[38:31],s1_result[28:21],s1_result[18:11],s1_result[8:1]};

	if (MASK_ENABLE_EXT) begin
		always @(*) begin
			case (s0_sew)
				2'b00:	w_s1_carry_result = {{(RESP_DATA_WIDTH-8){0}},s1_result[79],s1_result[69],s1_result[59],s1_result[49],s1_result[39],s1_result[29],s1_result[19],s1_result[9]};
				2'b01:	w_s1_carry_result = {{(RESP_DATA_WIDTH-4){0}},s1_result[79],s1_result[59],s1_result[39],s1_result[19]};
				2'b10:	w_s1_carry_result = {{(RESP_DATA_WIDTH-2){0}},s1_result[79],s1_result[39]};
				2'b11:	begin
					if (ENABLE_64_BIT) begin
						w_s1_carry_result = {{(RESP_DATA_WIDTH-1){0}},s1_result[79]};
					end else begin
						w_s1_carry_result = 'h0; // no 64-bit output
					end
				end
				default: w_s1_carry_result = 'h0; 
			endcase
		end
	end else begin
		always @(*) begin
			w_s1_carry_result = 'h0;
		end
	end

	vAdd_unit_block #(
		.REQ_DATA_WIDTH(REQ_DATA_WIDTH),
		.RESP_DATA_WIDTH(RESP_DATA_WIDTH),
		.SEW_WIDTH(SEW_WIDTH),
		.OPSEL_WIDTH(5),
		.ENABLE_64_BIT(ENABLE_64_BIT)
		)
	vAdd_unit0 (
		.clk   		(clk      		),
		.rst   		(rst      		),
		.vec0  		(s0_vec0  		),
		.vec1  		(s0_vec1  		),
		.carry  	(s0_carry_in 	),
		.sew   		(s0_sew   		),
		.opSel 		(s0_opSel[4:0]	),
		.result		(s1_result 		)
	);

	generate
		if (FXP_ENABLE) begin : fxp
			avg_unit #(
				.DATA_WIDTH(REQ_DATA_WIDTH),
				.ENABLE_64_BIT(ENABLE_64_BIT)
			) fxp_avg (
				.clk   	(clk		),
				.vec_in	(s2_out_vec	),
				.sew   	(s2_sew		),
				.v_d 	(avg_vd		),
				.v_d1  	(avg_vd1	),
				.vec_out(avg_vec_out)
			);
		end else begin
			assign avg_vd 		= 'h0;
			assign avg_vd1 		= 'h0;
			assign avg_vec_out 	= 'h0;
		end
	endgenerate

	always @(posedge clk) begin
		if(rst) begin
			s0_vec0    	<= 'b0;
			s0_vec1    	<= 'b0;

			s1_out_vec 	<= 'b0;
			s2_out_vec 	<= 'b0;
			s3_out_vec 	<= 'b0;
			s4_out_vec	<= 'b0;
			out_vec    	<= 'b0;

			s0_sew     	<= 'b0;
			s1_sew     	<= 'b0;
			s2_sew		<= 'b0;

			s0_opSel   	<= 'b0;
			s1_opSel   	<= 'b0;

			s0_valid   	<= 'b0;
			s1_valid   	<= 'b0;
			s2_valid   	<= 'b0;
			s3_valid   	<= 'b0;
			s4_valid 	<= 'b0;
			out_valid  	<= 'b0;

			s0_start_idx<= 'h0;
			s1_start_idx<= 'h0;
			s2_start_idx<= 'h0;

			s0_req_start<= 'b0;
			s1_req_start<= 'b0;
			s2_req_start<= 'b0;

			s0_req_end	<= 'b0;
			s1_req_end	<= 'b0;
			s2_req_end	<= 'b0;
			s3_req_end	<= 'b0;

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

			s0_carry_res<= 'b0;
			s1_carry_res<= 'b0;

			s0_carry_in	<= 'h0;

			s0_avg		<= 'b0;
			s1_avg		<= 'b0;
			s2_avg		<= 'b0;
			s3_avg		<= 'b0;
			s4_avg		<= 'b0;

			s4_vd 		<= 'b0;
			s4_vd1		<= 'b0;
			out_vd 		<= 'b0;
			out_vd1 	<= 'b0;
			out_fxp		<= 'b0;

			s0_out_be	<= 'h0;
			s1_out_be	<= 'h0;
			s2_out_be	<= 'h0;
			s3_out_be	<= 'h0;
			s4_out_be	<= 'h0;
			out_be 		<= 'h0;

			s2_mask	 	<= 'h0;
			s3_mask		<= 'h0;
			s4_mask		<= 'h0;
			out_mask	<= 'h0;
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

			if (MASK_ENABLE_EXT) begin
				case({(in_valid&in_mask&in_carry),in_opSel[1],in_sew})
					// adc/madc
					4'b1000: s0_carry_in <= {7'b0,in_be[7],7'b0,in_be[6],7'b0,in_be[5],7'b0,in_be[4],7'b0,in_be[3],7'b0,in_be[2],7'b0,in_be[1],7'b0,in_be[0]};
					4'b1001: s0_carry_in <= {15'b0,in_be[6],15'b0,in_be[4],15'b0,in_be[2],15'b0,in_be[0]};
					4'b1010: s0_carry_in <= {31'b0,in_be[4],31'b0,in_be[0]};
					4'b1011: begin
						if (ENABLE_64_BIT) begin
							s0_carry_in <= {63'b0,in_be[0]};
						end else begin
							s0_carry_in <= 'h0;
						end
					end
					// sbc/msbc
					4'b1100: s0_carry_in <= {{8{in_be[7]}},{8{in_be[6]}},{8{in_be[5]}},{8{in_be[4]}},{8{in_be[3]}},{8{in_be[2]}},{8{in_be[1]}},{8{in_be[0]}}};
					4'b1101: s0_carry_in <= {{16{in_be[6]}},{16{in_be[4]}},{16{in_be[2]}},{16{in_be[0]}}};
					4'b1110: s0_carry_in <= {{32{in_be[4]}},{32{in_be[0]}}};
					4'b1111: begin
						if (ENABLE_64_BIT) begin
							s0_carry_in <= {64{in_be[0]}};
						end else begin
							s0_carry_in <= 'h0;
						end
					end

					default: s0_carry_in <= 'h0;
				endcase
				s0_carry_res	<= ~in_mask & in_carry;
				s1_carry_res 	<= s0_carry_res;
			end else begin
				s0_carry_in 	<= 'h0;
				s0_carry_res	<= 'b0;
				s1_carry_res 	<= 'b0;
			end

			s1_sew   	<= s0_sew;
			s1_opSel 	<= s0_opSel;
			s1_valid   	<= s0_valid;
			s1_out_addr	<= s0_out_addr;
			s1_start_idx<= s0_start_idx;
			s1_req_end	<= s0_req_end;
			s1_req_start<= s0_req_start;
			s1_out_be 	<= s0_out_be;
			s1_avg 		<= s0_avg;

			if (MIN_MAX_ENABLE) begin
				if (MASK_ENABLE_EXT) begin
					case({s0_opSel[4],s0_carry_res})
						2'b00: s1_out_vec 	<=	w_s1_arith_result;
						2'b01: s1_out_vec 	<=	w_s1_carry_result;
						2'b10: s1_out_vec 	<=	w_minMax_result;
						default: s1_out_vec <= 'h0;
					endcase
				end else begin
					s1_out_vec 	<=	s0_opSel[4] ? w_minMax_result : w_s1_arith_result;
				end
			end else begin
				if (MASK_ENABLE_EXT) begin
					s1_out_vec 	<=	s0_carry_res ? w_s1_carry_result : w_s1_arith_result;
				end else begin
					s1_out_vec 	<=	w_s1_arith_result;
				end
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
	         	s3_mask 	<= 1'b0;
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

			if (MASK_ENABLE) begin
				out_mask 	<= s4_mask;
			end else begin
				out_mask 	<= 1'b0;
			end

			if (FXP_ENABLE) begin
				out_fxp		<= s4_avg;
				out_vd 		<= s4_vd;
				out_vd1 	<= s4_vd1;
			end else begin
				out_fxp 	<= 1'b0;
				out_vd 		<= 1'b0;
				out_vd1		<= 1'b0;
			end
		end
	end

	generate
		if (MASK_ENABLE) begin
			always @(posedge clk) begin
				if (MASK_ENABLE_EXT) begin
					s2_mask <= s1_opSel[8] | s1_carry_res;
				end else begin
					s2_mask <= s1_opSel[8];
				end
			end
		end else begin
			always @(*) begin
				s2_mask	= 1'b0;
			end
		end
	endgenerate

endmodule
