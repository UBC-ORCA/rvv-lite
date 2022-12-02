`include "mult32.v"
`include "operand_selector.v"

`define MIN(a,b) {(a < b) ? a : b}

module vMul #(
	parameter REQ_DATA_WIDTH  	= 64,
	parameter RESP_DATA_WIDTH 	= 64,
	parameter REQ_DW_B 			= REQ_DATA_WIDTH>>3,
	parameter REQ_ADDR_WIDTH 	= 32,
	parameter SEW_WIDTH       	= 2 ,
	parameter OPSEL_WIDTH     	= 2 , 
	parameter MULH_SR_ENABLE    = 0 ,
    parameter MULH_SR_32_ENABLE = 0 ,
    parameter WIDEN_MUL_ENABLE  = 0 ,
    parameter NARROW_ENABLE		= 0 ,
    parameter MUL64_ENABLE    	= 0 ,
    parameter SHIFTR64_ENABLE 	= 0 ,
	parameter FXP_ENABLE		= 0 ,
	parameter ENABLE_64_BIT 	= 0 ,
	parameter EN_128_MUL		= 0
) (
	input                            	clk,
	input                            	rst,
	input      	[ REQ_DATA_WIDTH-1:0] 	in_vec0,
	input      	[ REQ_DATA_WIDTH-1:0] 	in_vec1,
	input                            	in_valid,
	input      	[  	   SEW_WIDTH-1:0] 	in_sew,
	input      	[    OPSEL_WIDTH-1:0] 	in_opSel,
	input                            	in_widen,
	input 	 	[ REQ_ADDR_WIDTH-1:0] 	in_addr,
	input 								in_fxp_s,
	input 								in_fxp_mul,
	input 								in_sr_64,
	input 								in_or_top,
	input 								in_vd10,
	input 		[ 				 7:0]	in_shift,
	input 								in_narrow,
	output reg 	[RESP_DATA_WIDTH-1:0] 	out_vec,
	output reg							out_fxp,
	output reg                       	out_valid,
	output reg 	[ REQ_ADDR_WIDTH-1:0] 	out_addr,
	output reg 	[		REQ_DW_B-1:0]	out_vd,
	output reg 	[		REQ_DW_B-1:0]	out_vd1,
	output reg 	[		REQ_DW_B-1:0]	out_vd10,
	output reg 							out_narrow
);

	//Wires
	wire signed [17:0]	m0_a0, m0_b0, m0_a1, m0_b1, m1_a0, m1_b0, m1_a1, m1_b1, m2_a0, m2_b0, m2_a1, m2_b1, m3_a0, m3_b0, m3_a1, m3_b1;
	wire signed [33:0] 	m0_p0, m0_p1, m1_p0, m1_p1, m2_p0, m2_p1, m3_p0, m3_p1;
	wire signed [66:0] 	m0_mult32, m1_mult32, m2_mult32, m3_mult32;

	// if (EN_128_MUL) begin
		wire signed [129:0] w_s3_d0;
		wire signed [129:0] w_add0;
		wire signed [129:0] w_add1;
	// end else begin
	// 	wire signed [70:0] 	w_s3_d0;
	// 	wire signed [70:0] 	w_add0;
	// 	wire signed [70:0] 	w_add1;
	// end

	//Registers
	reg signed [16:0] 	s4_b7, s4_b6, s4_b5, s4_b4, s4_b3, s4_b2, s4_b1, s4_b0;

	reg signed [32:0] 	s4_h0, s4_h1, s4_h2, s4_h3;

	reg signed [64:0] 	s4_w0, s4_w1;

	reg signed[129:0] 	s4_d0;

	reg 						s0_valid, s1_valid, s2_valid, s3_valid, s4_valid;
	reg [REQ_ADDR_WIDTH-1:0]	s0_out_addr, s1_out_addr, s2_out_addr, s3_out_addr, s4_out_addr;
	reg [	  SEW_WIDTH-1:0]	s0_sew, s1_sew, s2_sew, s3_sew, s4_sew;
	reg                 		s0_lsb, s1_lsb, s2_lsb, s3_lsb, s4_lsb;
	reg                 		s0_fxp_s, s1_fxp_s, s2_fxp_s, s3_fxp_s, s4_fxp_s;
	reg                 		s0_fxp_mul, s1_fxp_mul, s2_fxp_mul, s3_fxp_mul, s4_fxp_mul;
	reg                 		s0_sr_64, s1_sr_64, s2_sr_64, s3_sr_64, s4_sr_64;
	reg                 		s0_or_top, s1_or_top, s2_or_top, s3_or_top, s4_or_top;
	reg 						s0_vd10, s1_vd10, s2_vd10, s3_vd10, s4_vd10; // for 64-bit
	reg                 		s0_narrow, s1_narrow, s2_narrow, s3_narrow, s4_narrow;

	reg signed [		24:0] 	s0_top_bits, s1_top_bits; // keep signed for sra
	reg [ 				24:0]	s2_top_bits, s3_top_bits, s4_top_bits;
	reg [ 				 5:0]	s0_shift, s1_shift, s2_shift, s3_shift;


	
	generate
		if(MUL64_ENABLE & REQ_DATA_WIDTH > 32) begin
			if (EN_128_MUL) begin
				assign w_add0 = {m0_mult32,64'b0} + {{64{m3_mult32[65]}},m3_mult32[65:0]};
				assign w_add1 = {{32{m1_mult32[65]}},m1_mult32[65:0],32'b0} + {{32{m2_mult32[65]}},m2_mult32[65:0],32'b0};
				assign w_s3_d0 = w_add0 + w_add1;
			end else begin
				assign w_add0 	= m3_mult32[65:0];
				assign w_add1 	= m0_mult32[65:0] + m2_mult32[65:0];
				assign w_s3_d0 	= w_add0 + {w_add1,32'b0};
			end
		end
		else begin
			assign w_s3_d0 	= 'b0;
		end
	endgenerate

	// 1 cycle (in -> s1)
	operand_select #(
		.INPUT_WIDTH(REQ_DATA_WIDTH),
		.OPSEL_WIDTH(OPSEL_WIDTH),
		.SEW_WIDTH(SEW_WIDTH),
		.ENABLE_64_BIT(ENABLE_64_BIT),
		.EN_128_MUL(EN_128_MUL)
	) opSelector (
		.clk 	(clk 		),
		.rst  	(rst     	),
		.vec0 	(in_vec0 	),
		.vec1 	(in_vec1 	),
		.valid	(in_valid	),
		.sew  	(in_sew		),
		.opSel	(in_opSel	),
		.m0_a0	(m0_a0   	),
		.m0_a1	(m0_a1   	),
		.m0_b0	(m0_b0   	),
		.m0_b1	(m0_b1   	),
		.m1_a0	(m1_a0   	),
		.m1_a1	(m1_a1   	),
		.m1_b0	(m1_b0   	),
		.m1_b1	(m1_b1   	),
		.m2_a0	(m2_a0   	),
		.m2_a1	(m2_a1   	),
		.m2_b0	(m2_b0   	),
		.m2_b1	(m2_b1   	),
		.m3_a0	(m3_a0   	),
		.m3_a1	(m3_a1   	),
		.m3_b0	(m3_b0   	),
		.m3_b1	(m3_b1   	)
	);


	// 1 cycle (s1 -> s2)
	mult32 m0 (
		.clk			(clk		),
		.rst 			(rst 		),
		.in_a0 			(m0_a0		),
		.in_a1 			(m0_a1		),
		.in_b0 			(m0_b0		),
		.in_b1 			(m0_b1		),
		.out_mult8_b0 	(m0_bout0	),
		.out_mult8_b1 	(m0_bout1	),
		.out_mult8_b2 	(m0_bout2	),
		.out_mult8_b3 	(m0_bout3	),
		.out_mult16_p0 	(m0_p0		),
		.out_mult16_p1 	(m0_p1		),
		.out_mult32 	(m0_mult32	)
	);

	mult32 m1 (
		.clk			(clk		),
		.rst 			(rst		),
		.in_a0			(m1_a0		),
		.in_a1			(m1_a1		),
		.in_b0			(m1_b0		),
		.in_b1			(m1_b1		),
		// .out_mult16_p0	(m1_p0		),
		// .out_mult16_p1	(m1_p1		),
		.out_mult32		(m1_mult32	)
	);

	mult32 m2 (
		.clk			(clk		),
		.rst 			(rst		),
		.in_a0 			(m2_a0		),
		.in_a1 			(m2_a1		),
		.in_b0 			(m2_b0		),
		.in_b1 			(m2_b1		),
		// .out_mult16_p0	(m2_p0		),
		// .out_mult16_p1	(m2_p1		),
		.out_mult32		(m2_mult32	)
	);


	mult32 m3 (
		.clk			(clk		),
		.rst			(rst 		),
		.in_a0			(m3_a0		),
		.in_a1			(m3_a1		),
		.in_b0			(m3_b0		),
		.in_b1			(m3_b1		),
		.out_mult8_b0 	(m3_bout0	),
		.out_mult8_b1 	(m3_bout1	),
		.out_mult8_b2 	(m3_bout2	),
		.out_mult8_b3 	(m3_bout3	),
		.out_mult16_p0	(m3_p0		),
		.out_mult16_p1	(m3_p1		),
		.out_mult32		(m3_mult32	)
	);

generate
	if (SHIFTR64_ENABLE & ~EN_128_MUL & REQ_DATA_WIDTH > 32) begin
		always @(posedge clk) begin
			if (rst) begin
				s0_shift	<= 'h0;
				s1_shift	<= 'h0;
				s2_shift 	<= 'h0;
				s3_shift 	<= 'h0;

				s0_top_bits	<= 'h0;
				s1_top_bits <= 'h0; 
				s2_top_bits <= 'h0; 
				s3_top_bits <= 'h0; 
				s4_top_bits <= 'h0;

				s0_sr_64 	<= 'b0;
				s1_sr_64 	<= 'b0;
				s2_sr_64 	<= 'b0;
				s3_sr_64 	<= 'b0;
				s4_sr_64 	<= 'b0;

				s0_or_top 	<= 'b0;
				s1_or_top 	<= 'b0;
				s2_or_top 	<= 'b0;
				s3_or_top 	<= 'b0;
				s4_or_top 	<= 'b0;
			end else begin
				s0_shift	<= in_valid ? in_shift[5:0] : 'h0;
				s1_shift	<= 'h0;//(s0_shift > 7 ? s0_shift - 7 : 0);
				s2_shift 	<= 'h0;//(s1_shift > 6 ? s1_shift - 6 : 0);
				s3_shift 	<= 'h0;//(s2_shift > 6 ? s2_shift - 7 : 0);

				s0_top_bits	<= in_valid	? in_vec0[63:39] : 'h0;
				s1_top_bits <= s0_top_bits >> s0_shift;
				s2_top_bits <= s1_top_bits;// >> (s1_shift > 6 ? 6 : s1_shift));
				s3_top_bits <= s2_top_bits;// >> (s2_shift > 6 ? 6 : s2_shift));
				s4_top_bits <= s3_top_bits;// >> s3_shift);

				s0_sr_64	<= in_valid ? in_sr_64 : 'b0;
				s1_sr_64	<= s0_sr_64;
				s2_sr_64	<= s1_sr_64;
				s3_sr_64	<= s2_sr_64;
				s4_sr_64 	<= s3_sr_64;

				s0_or_top 	<= in_valid & in_or_top;
				s1_or_top 	<= s0_or_top;
				s2_or_top 	<= s1_or_top;
				s3_or_top 	<= s2_or_top;
				s4_or_top 	<= s3_or_top;
			end
		end
	end

	if (NARROW_ENABLE) begin
		always @(posedge clk) begin
			if (rst) begin
				s0_narrow 	<= 0;
				s1_narrow 	<= 0;
				s2_narrow 	<= 0;
				s3_narrow 	<= 0;
				s4_narrow 	<= 0;
				out_narrow  <= 0;
			end else begin
				s0_narrow 	<= in_valid & in_narrow;
				s1_narrow 	<= s0_narrow;
				s2_narrow 	<= s1_narrow;
				s3_narrow 	<= s2_narrow;
				s4_narrow 	<= s3_narrow;
				out_narrow 	<= s4_narrow;
			end
		end
	end else begin
		always @(*) begin
			out_narrow	= 'b0;
		end
	end
endgenerate

	always @(posedge clk) begin
		if(rst) begin
			s4_b2     	<= 'b0;
			s4_b3     	<= 'b0;
			s4_b4     	<= 'b0;
			s4_b5     	<= 'b0;
			s4_h3     	<= 'b0;
			s4_h2     	<= 'b0;
			s4_h1     	<= 'b0;
			s4_h0     	<= 'b0;
			s4_w1     	<= 'b0;
			s4_w0     	<= 'b0;
			s4_d0     	<= 'b0;

			s0_valid  	<= 'b0;
			s1_valid  	<= 'b0;
			s2_valid  	<= 'b0;
			s3_valid  	<= 'b0;
			s4_valid  	<= 'b0;
			out_valid 	<= 'b0;

			s0_sew    	<= 'b0;
			s1_sew    	<= 'b0;
			s2_sew    	<= 'b0;
			s3_sew    	<= 'b0;
			s4_sew    	<= 'b0;

			s0_out_addr	<= 'b0;
			s1_out_addr <= 'b0;
			s2_out_addr <= 'b0;
			s3_out_addr <= 'b0;
			s4_out_addr <= 'b0;
			out_addr	<= 'b0;
		end else begin
			s4_b7     	<= m0_bout0;
			s4_b6     	<= m0_bout1;
			s4_b5     	<= m0_bout2;
			s4_b4     	<= m0_bout3;
			s4_b3     	<= m3_bout0;
			s4_b2     	<= m3_bout1;
			s4_b1     	<= m3_bout2;
			s4_b0     	<= m3_bout3;

			s4_h3     	<= m0_p0;
			s4_h2     	<= m0_p1;
			s4_h1     	<= m3_p0;
			s4_h0     	<= m3_p1;

			s4_w1     	<= m0_mult32;
			s4_w0     	<= m3_mult32;

			s4_d0     	<= w_s3_d0;

			s0_valid  	<= in_valid;
			s1_valid  	<= s0_valid;
			s2_valid  	<= s1_valid;
			s3_valid  	<= s2_valid;
			s4_valid  	<= s3_valid;
			out_valid 	<= s4_valid;

			s0_sew    	<= in_valid ? in_sew : 'h0;
			s1_sew    	<= s0_sew;
			s2_sew    	<= s1_sew;
			s3_sew    	<= s2_sew;
			s4_sew    	<= s3_sew;

			s0_out_addr	<= in_valid ? in_addr : 'h0;
			s1_out_addr <= s0_out_addr;
			s2_out_addr <= s1_out_addr;
			s3_out_addr <= s2_out_addr;
			s4_out_addr <= s3_out_addr;
			out_addr	<= s4_out_addr;
		end
	end

	generate
		if (MULH_SR_ENABLE) begin
			always @(posedge clk) begin
				if(rst) begin
					s0_lsb    	<= 'b0;
					s1_lsb    	<= 'b0;
					s2_lsb    	<= 'b0;
					s3_lsb    	<= 'b0;
					s4_lsb    	<= 'b0;
				end else begin
					if (WIDEN_MUL_ENABLE) begin
						s0_lsb    	<= (~in_opSel[1] & in_opSel[0] | in_widen) & in_valid;
					end else begin
						s0_lsb    	<= (~in_opSel[1] & in_opSel[0]) & in_valid;
					end
					s1_lsb    	<= s0_lsb;
					s2_lsb    	<= s1_lsb;
					s3_lsb    	<= s2_lsb;
					s4_lsb    	<= s3_lsb;
				end
			end
		end else begin
			always @(*) begin
				s4_lsb 	<= 'b1;
			end
		end

		if (FXP_ENABLE) begin : fxp_shift_mul
			always @(posedge clk) begin
				if(~rst) begin
					s0_fxp_s   	<= 'b0;
					s1_fxp_s   	<= 'b0;
					s2_fxp_s   	<= 'b0;
					s3_fxp_s   	<= 'b0;
					s4_fxp_s   	<= 'b0;

					s0_fxp_mul 	<= 'b0;
					s1_fxp_mul 	<= 'b0;
					s2_fxp_mul 	<= 'b0;
					s3_fxp_mul 	<= 'b0;
					s4_fxp_mul 	<= 'b0;
				end else begin
					s0_fxp_s    <= in_valid & in_fxp_s;
					s1_fxp_s    <= s0_fxp_s;
					s2_fxp_s    <= s1_fxp_s;
					s3_fxp_s    <= s2_fxp_s;
					s4_fxp_s    <= s3_fxp_s;

					s0_fxp_mul	<= in_valid & in_fxp_mul;
					s1_fxp_mul	<= s0_fxp_mul;
					s2_fxp_mul	<= s1_fxp_mul;
					s3_fxp_mul	<= s2_fxp_mul;
					s4_fxp_mul	<= s3_fxp_mul;
				end
			end
		end else begin
			always @(*) begin
				s4_fxp_s 	= 'b0;
				s4_fxp_mul	= 'b0;
			end
		end

		always @(posedge clk) begin
			if(rst) begin
				out_vec <= 'b0;
			end 
			else begin
				if (REQ_DATA_WIDTH > 32) begin
					case ({s4_fxp_mul,s4_lsb,s4_sew})
						'b0000 : out_vec <= {s4_b7[15:8],s4_b6[15:8],s4_b5[15:8],s4_b4[15:8],s4_b3[15:8],s4_b2[15:8],s4_b1[15:8],s4_b0[15:8]};
						'b0001 : out_vec <= {s4_h3[31:16], s4_h2[31:16], s4_h1[31:16], s4_h0[31:16]};
						'b0010 : begin
							if (MULH_SR_32_ENABLE) begin
								out_vec <= {s4_w1[63:32], s4_w0[63:32]};
							end else begin
								out_vec	<= 'h0;
							end
						end
						'b0011 : begin
							if (ENABLE_64_BIT) begin
								if (EN_128_MUL) begin
									out_vec <= s4_d0[127:64];
								end else begin
									out_vec <= (s4_sr_64 ? (s4_or_top ? {s4_top_bits[24:0],s4_d0[70:32]} : {{32{s4_d0[63]}},s4_d0[63:32]}) : 'h0);
								end
							end else begin
								out_vec <= 'h0;
							end
						end
						'b0100 : out_vec <= {s4_b7[7:0],s4_b6[7:0],s4_b5[7:0],s4_b4[7:0],s4_b3[7:0],s4_b2[7:0],s4_b1[7:0],s4_b0[7:0]};
						'b0101 : out_vec <= {s4_h3[15:0], s4_h2[15:0], s4_h1[15:0], s4_h0[15:0]};
						'b0110 : out_vec <= {s4_w1[31:0], s4_w0[31:0]};
						'b0111 : begin
							if (WIDEN_MUL_ENABLE & ENABLE_64_BIT) begin
								if (MUL64_ENABLE) begin
									out_vec <= s4_d0[63:0];
								end else begin
									out_vec <= s4_w0[63:0]; // s4_lsb is set when s4_widen is high
								end
							end else begin
								out_vec <= 'h0;
							end
						end
						'b1000 : begin
							if (FXP_ENABLE) begin
								out_vec <= {s4_b7[11:4],s4_b6[11:4],s4_b5[11:4],s4_b4[11:4],s4_b3[11:4],s4_b2[11:4],s4_b1[11:4],s4_b0[11:4]};
							end else begin
								out_vec <= 'h0;
							end
						end
						'b1001 : begin
							if (FXP_ENABLE) begin
								out_vec <= {s4_h3[23:8], s4_h2[23:8], s4_h1[23:8], s4_h0[23:8]};
							end else begin
								out_vec <= 'h0;
							end
						end
						'b1010 : begin
							if (FXP_ENABLE) begin
								out_vec <= {s4_w1[47:16], s4_w0[47:16]};
							end else begin
								out_vec <= 'h0;
							end
						end
						'b1011 : begin
							if (FXP_ENABLE & EN_128_MUL & ENABLE_64_BIT) begin
								out_vec <= {s4_d0[91:32]};
							end else begin
								out_vec <= 'h0;
							end
						end
						default : out_vec 	<= 'h0;
					endcase
				end else begin
					case ({s4_fxp_mul,s4_lsb,s4_sew})
						'b0000 : out_vec <= {s4_b3[15:8],s4_b2[15:8],s4_b1[15:8],s4_b0[15:8]};
						'b0001 : out_vec <= {s4_h1[31:16], s4_h0[31:16]};
						'b0010 : begin
							if (MULH_SR_32_ENABLE) begin
								out_vec <= {s4_w0[63:32]};
							end else begin
								out_vec	<= 'h0;
							end
						end
						'b0100 : out_vec <= {s4_b7[7:0],s4_b6[7:0],s4_b5[7:0],s4_b4[7:0],s4_b3[7:0],s4_b2[7:0],s4_b1[7:0],s4_b0[7:0]};
						'b0101 : out_vec <= {s4_h3[15:0], s4_h2[15:0], s4_h1[15:0], s4_h0[15:0]};
						'b0110 : out_vec <= {s4_w1[31:0], s4_w0[31:0]};
						'b1000 : begin
							if (FXP_ENABLE) begin
								out_vec <= {s4_b3[11:4],s4_b2[11:4],s4_b1[11:4],s4_b0[11:4]};
							end else begin
								out_vec <= 'h0;
							end
						end
						'b1001 : begin
							if (FXP_ENABLE) begin
								out_vec <= {s4_h1[23:8], s4_h0[23:8]};
							end else begin
								out_vec <= 'h0;
							end
						end
						'b1010 : begin
							if (FXP_ENABLE) begin
								out_vec <= {s4_w0[47:16]};
							end else begin
								out_vec <= 'h0;
							end
						end
						default : out_vec 	<= 'h0;
					endcase
				end
			end
		end
		if (FXP_ENABLE) begin
			always @(posedge clk) begin
				if(rst) begin
					out_fxp <= 'b0;
				end else begin
					out_fxp <= s4_fxp_mul | s4_fxp_s;
				end
			end
			always @(posedge clk) begin
				if(rst) begin
					out_vd <= 'b0;
				end 
				else begin
					case ({s4_fxp_mul, s4_sew})
						'b000 : out_vd	<= s4_fxp_s ? {s4_b7[8],s4_b6[8],s4_b5[8],s4_b4[8],s4_b3[8],s4_b2[8],s4_b1[8],s4_b0[8]} : 'h0;
						'b001 : out_vd	<= s4_fxp_s ? {1'b0, s4_h3[16], 1'b0, s4_h2[16], 1'b0, s4_h1[16], 1'b0, s4_h0[16]} : 'h0;
						'b010 : out_vd	<= s4_fxp_s ? {3'b0, s4_w1[32], 3'b0, s4_w0[32]} : 'h0;
						'b011 : begin
							if (ENABLE_64_BIT) begin
								if (EN_128_MUL) begin
									out_vd 	<= s4_fxp_s ? {7'b0, s4_d0[64]} : 'h0;
								end else begin
									out_vd 	<= s4_fxp_s ? {7'b0, s4_d0[32]} : 'h0;
								end
							end else begin
								out_vd 	<= 'h0;
							end
						end

						'b100 : out_vd	<= {s4_b7[3],s4_b6[3],s4_b5[3],s4_b4[3],s4_b3[3],s4_b2[3],s4_b1[3],s4_b0[3]};
						'b101 : out_vd	<= {1'b0, s4_h3[7], 1'b0, s4_h2[7], 1'b0, s4_h1[7], 1'b0, s4_h0[7]};
						'b110 : out_vd 	<= {3'b0, s4_w1[15], 3'b0, s4_w0[15]};
						'b111 : begin
							if (ENABLE_64_BIT & EN_128_MUL & REQ_DATA_WIDTH > 32) begin
								out_vd 	<= {7'b0, s4_d0[31]};
							end else begin
								out_vd	<= 'h0;
							end
						end
						default: out_vd	<= 'h0;
					endcase
				end
			end

			always @(posedge clk) begin
				if(rst) begin
					out_vd1 <= 'b0;
				end 
				else begin
					case ({s4_fxp_mul, s4_sew})
						'b000 : out_vd1 <= s4_fxp_s ? {s4_b7[7],s4_b6[7],s4_b5[7],s4_b4[7],s4_b3[7],s4_b2[7],s4_b1[7],s4_b0[7]} : 'h0;
						'b001 : out_vd1 <= s4_fxp_s ? {1'b0, s4_h3[15], 1'b0, s4_h2[15], 1'b0, s4_h1[15], 1'b0, s4_h0[15]} : 'h0;
						'b010 : out_vd1 <= s4_fxp_s ? {3'b0, s4_w1[31], 3'b0, s4_w0[31]} : 'h0;
						'b011 : begin
							if (ENABLE_64_BIT) begin
								if (EN_128_MUL) begin
									out_vd1	<= s4_fxp_s ? {7'b0, s4_d0[63]} : 'h0;
								end else begin
									out_vd1 <= s4_fxp_s ? {7'b0, s4_d0[31]} : 'h0;
								end
							end else begin
								out_vd1 <= 'h0;
							end
						end

						'b100 : out_vd1 <= {s4_b7[3],s4_b6[3],s4_b5[3],s4_b4[3],s4_b3[3],s4_b2[3],s4_b1[3],s4_b0[3]};
						'b101 : out_vd1 <= {1'b0, s4_h3[7], 1'b0, s4_h2[7], 1'b0, s4_h1[7], 1'b0, s4_h0[7]};
						'b110 : out_vd1 <= {3'b0, s4_w1[15], 3'b0, s4_w0[15]};
						'b111 : begin
							if (ENABLE_64_BIT & EN_128_MUL & REQ_DATA_WIDTH > 32) begin
								out_vd1 <= {7'b0, s4_d0[31]};
							end else begin
								out_vd1 <= 'h0;
							end
						end
						default: out_vd1 <= 'h0;
					endcase
				end
			end

			always @(posedge clk) begin
				if(rst) begin
					out_vd10 <= 'b0;
				end 
				else begin
					case ({s4_fxp_mul, s4_sew})
						'b000 : out_vd10 <= s4_fxp_s ? {(|s4_b7[7:0]),(|s4_b6[7:0]),(|s4_b5[7:0]),(|s4_b4[7:0]),(|s4_b3[7:0]),(|s4_b2[7:0]),(|s4_b1[7:0]),(|s4_b0[7:0])} : 'h0;
						'b001 : out_vd10 <= s4_fxp_s ? {1'b0, |(s4_h3[15:0]), 1'b0, (|s4_h2[15:0]), 1'b0, (|s4_h1[15:0]), 1'b0, (|s4_h0[15:0])} : 'h0;
						'b010 : out_vd10 <= s4_fxp_s ? {3'b0, (|s4_w1[31:0]), 3'b0, (|s4_w0[31:0])} : 'h0;
						'b011 : begin
							if (ENABLE_64_BIT) begin
								if (EN_128_MUL) begin
									out_vd10 <= s4_fxp_s ? {7'b0, (|s4_d0[63:0])} : 'h0;
								end else begin
									out_vd10 <= s4_fxp_s ? {7'b0, ((|s4_d0[31:0]) | s4_vd10)} : 'h0;
								end
							end else begin
								out_vd10 <= 'h0;
							end
						end

						'b100 : out_vd10 <= {(|s4_b7[3:0]),(|s4_b6[3:0]),(|s4_b5[3:0]),(|s4_b4[3:0]),(|s4_b3[3:0]),(|s4_b2[3:0]),(|s4_b1[3:0]),(|s4_b0[3:0])};
						'b101 : out_vd10 <= {1'b0, (|s4_h3[7:0]), 1'b0, (|s4_h2[7:0]), 1'b0, (|s4_h1[7:0]), 1'b0, (|s4_h0[7:0])};
						'b110 : out_vd10 <= {3'b0, (|s4_w1[15:0]), 3'b0, (|s4_w0[15:0])};
						'b111 : begin
							if (ENABLE_64_BIT & EN_128_MUL & REQ_DATA_WIDTH >= 64) begin
								out_vd10 <= {7'b0, (|s4_d0[31:0])};
							end else begin
								out_vd10 <= 'h0;
							end
						end

						default: out_vd10 <= 'h0;
					endcase
				end
			end
		end else begin // Not FXP
			always @(*) begin
				out_vd 	 = 'b0;
				out_vd1  = 'b0;
				out_vd10 = 'b0;
				out_fxp  = 'b0;
			end
		end
	endgenerate

endmodule