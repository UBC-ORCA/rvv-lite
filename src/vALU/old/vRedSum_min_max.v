`include "vRedSum_Min_Max_unit_block.v"

`define MIN(a,b) {(a > b) ? b : a}

module vRedSum_min_max #(
	parameter REQ_DATA_WIDTH    = 64,
	parameter REQ_BE_WIDTH		= REQ_DATA_WIDTH/8,
	parameter RESP_DATA_WIDTH   = 64,
	parameter REQ_ADDR_WIDTH 	= 32,
	parameter OPSEL_WIDTH       = 5,
	parameter SEW_WIDTH         = 2,
	parameter ENABLE_64_BIT		= 1
) (
	input								clk,
	input 								rst,
	input      	[ REQ_DATA_WIDTH-1:0] 	in_vec0,
	input      	[ REQ_DATA_WIDTH-1:0] 	in_vec1,
	input                              	in_valid,
	input							   	in_start,
	input                              	in_end,
	input      	[	 OPSEL_WIDTH-1:0] 	in_opSel, 
	input      	[	   SEW_WIDTH-1:0] 	in_sew,
	input		[ REQ_ADDR_WIDTH-1:0] 	in_addr,
	output reg 	[RESP_DATA_WIDTH-1:0] 	out_vec,
	output reg 	[ REQ_ADDR_WIDTH-1:0] 	out_addr,
	output reg                         	out_valid,
	output reg 	[	REQ_BE_WIDTH-1:0]	out_be
);

	reg	[ REQ_DATA_WIDTH-1:0] 	s0_vec0;
	reg [ 	 OPSEL_WIDTH-1:0] 	s0_opSel, s1_opSel, s2_opSel, s3_opSel;
	reg [ 	   SEW_WIDTH-1:0] 	s0_sew, s1_sew, s2_sew, s3_sew, s4_sew;
	reg 						s0_start, s1_start, s2_start, s3_start;
	reg 						s0_end, s1_end, s2_end, s3_end, s4_end;
	reg [ REQ_DATA_WIDTH-1:0]	s0_vec1, s1_vec1, s2_vec1, s3_vec1;
	reg [ REQ_ADDR_WIDTH-1:0] 	s0_out_addr, s1_out_addr, s2_out_addr, s3_out_addr, s4_out_addr;

	wire [REQ_DATA_WIDTH-1:0]	s1_out, s2_out, s3_out, s4_out;
	reg  [	REQ_BE_WIDTH-1:0]	s4_be;

	vRedSum_min_max_unit_block # (
		.REQ_DATA_WIDTH	(64)
	) b64 (
		.clk		(clk									),
		.rst		(rst									),
		.vec0		({s3_out,(s3_start ? s3_vec1 : s4_out)}	),
		.sew		(s3_sew									),
		.en			(1'b1									),
		.opSel		(s3_opSel								),
		.out_vec	(s4_out 								)
	);

	vRedSum_min_max_unit_block # (
		.REQ_DATA_WIDTH	(32)
	) b32 (
		.clk	(clk			),
		.rst	(rst			),
		.vec0	(s0_vec0		),
		.sew	(s0_sew 		),
		.en		(s0_sew < 2'b11	),
		.opSel 	(s0_opSel		),
		.out_vec(s1_out 		)
	);
	

	vRedSum_min_max_unit_block # (
		.REQ_DATA_WIDTH	(16)
	) b16 (
		.clk	(clk			),
		.rst	(rst			),
		.vec0	(s1_out			),
		.sew	(s1_sew			),
		.en		(s1_sew < 2'b10	),
		.opSel	(s1_opSel 		),
		.out_vec(s2_out 		)
	);


	vRedSum_min_max_unit_block # (
		.REQ_DATA_WIDTH	(8)
	) b8 (
		.clk	(clk			),
		.rst	(rst			),
		.vec0	(s2_out			),
		.sew	(s2_sew			),
		.en		(s2_sew < 2'b01	),
		.opSel	(s2_opSel 		),
		.out_vec(s3_out 		)
	);

	always @(posedge clk) begin
		if(rst) begin
			s0_vec0 	<= 'b0;
			s0_opSel 	<= 'b0;
			s1_opSel 	<= 'b0;
			s2_opSel 	<= 'b0;
			s3_opSel 	<= 'b0;

			s0_sew 		<= 'b0;
			s1_sew 		<= 'b0;
			s2_sew 		<= 'b0;
			s3_sew 		<= 'b0;

			s0_start 	<= 'b0;
			s1_start 	<= 'b0;
			s2_start 	<= 'b0;
			s3_start 	<= 'b0;

			s0_vec1 	<= 'b0;
			s1_vec1 	<= 'b0;
			s2_vec1 	<= 'b0;
			s3_vec1 	<= 'b0;
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
			s0_vec0 	<= in_valid ? in_vec0 : 'h0; // 	& {REQ_DATA_WIDTH{in_valid}};
			s0_opSel 	<= in_valid ? in_opSel : 'h0; //	& {OPSEL_WIDTH{in_valid}};
			s1_opSel 	<= s0_opSel;
			s2_opSel 	<= s1_opSel;
			s3_opSel 	<= s2_opSel;

			// if (ENABLE_64_BIT) begin
				s0_sew 		<= in_valid ? in_sew : 'h0; // 	& {SEW_WIDTH{in_valid}};
			// end else begin
			// 	s0_sew 		<= in_valid ? `MIN(in_sew, 2'b10) : 'h0; // 	& {SEW_WIDTH{in_valid}};
			// end
			s1_sew 		<= s0_sew;
			s2_sew 		<= s1_sew;
			s3_sew 		<= s2_sew;
			s4_sew		<= s3_sew;

			s0_start 	<= in_start	& in_valid;
			s1_start 	<= s0_start;
			s2_start 	<= s1_start;
			s3_start 	<= s2_start;

			s0_vec1 	<= in_vec1;
			s1_vec1 	<= s0_vec1;
			s2_vec1 	<= s1_vec1;
			s3_vec1 	<= s2_vec1;

			s0_end 		<= in_end	& in_valid;
			s1_end 		<= s0_end;
			s2_end 		<= s1_end;
			s3_end 		<= s2_end;
			s4_end 		<= s3_end;
			out_valid 	<= s4_end;
			out_vec 	<= s4_end ? s4_out : 'b0;

			s0_out_addr	<= in_valid ? in_addr : 'h0; // 	& {REQ_ADDR_WIDTH{in_valid}};
			s1_out_addr	<= s0_out_addr;
			s2_out_addr	<= s1_out_addr;
			s3_out_addr	<= s2_out_addr;
			s4_out_addr	<= s3_out_addr;
			out_addr 	<= s4_out_addr;


			out_be 		<= s4_be;
		end
	end

	always @(*) begin
		case ({s4_end, s4_sew})
			3'b100:	s4_be = 'h1;
			3'b101:	s4_be = 'h3;
			3'b110:	s4_be = 'h7;
			3'b111: begin
				if (ENABLE_64_BIT) begin
					s4_be = 'hF;
				end
				// else begin
					// s4_be = 'h0;
				// end
			end
			default:s4_be = 'h0;
		endcase
	end

endmodule