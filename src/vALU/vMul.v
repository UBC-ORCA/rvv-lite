`include "mult32.v"
`include "operand_selector.v"

module vMul #(
	parameter REQ_DATA_WIDTH  	= 64,
	parameter RESP_DATA_WIDTH 	= 64,
	parameter REQ_DW_B 			= REQ_DATA_WIDTH>>3,
	parameter REQ_ADDR_WIDTH 	= 32,
	parameter SEW_WIDTH       	= 2 ,
	parameter OPSEL_WIDTH     	= 2 , 
	parameter MUL64_ENABLE    	= 0 ,
	parameter FXP_ENABLE		= 0
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
	output reg 	[RESP_DATA_WIDTH-1:0] 	out_vec,
	output reg                       	out_valid,
	output reg 	[ REQ_ADDR_WIDTH-1:0] 	out_addr,
	output reg 	[		REQ_DW_B-1:0]	out_vd,
	output reg 	[		REQ_DW_B-1:0]	out_vd1,
	output reg 	[		REQ_DW_B-1:0]	out_vd10
);

	//Wires
	wire signed [17:0]	m0_a0, m0_b0, m0_a1, m0_b1, m1_a0, m1_b0, m1_a1, m1_b1, m2_a0, m2_b0, m2_a1, m2_b1, m3_a0, m3_b0, m3_a1, m3_b1;
	wire signed [33:0] 	m0_p0, m0_p1, m1_p0, m1_p1, m2_p0, m2_p1, m3_p0, m3_p1;
	wire signed [66:0] 	m0_mult32, m1_mult32, m2_mult32, m3_mult32;

	//wire signed [133:0] w_s3_d0;
	//wire signed [131:0] w_add0;
	//wire signed [131:0] w_add1;

	wire signed [70:0] 	w_s3_d0;
	wire signed [70:0] 	w_add0;
	wire signed [70:0] 	w_add1;

	//Registers
	reg signed [17:0] 	s3_b5, s3_b4, s3_b3, s3_b2;

	reg signed [32:0] 	s3_h0, s3_h1, s3_h2, s3_h3;

	reg signed [66:0] 	s3_w0, s3_w1;

	//reg signed [133:0] s3_d0;
	reg signed[70:0] 	s3_d0;

	reg 						s0_valid, s1_valid, s2_valid, s3_valid, s4_valid;
	reg [REQ_ADDR_WIDTH-1:0]	s0_out_addr, s1_out_addr, s2_out_addr, s3_out_addr, s4_out_addr;
	reg [	  SEW_WIDTH-1:0]	s0_sew, s1_sew, s2_sew, s3_sew, s4_sew;
	reg                 		s0_lsb, s1_lsb, s2_lsb, s3_lsb, s4_lsb;
	reg                 		s0_fxp_s, s1_fxp_s, s2_fxp_s, s3_fxp_s, s4_fxp_s;
	reg                 		s0_fxp_mul, s1_fxp_mul, s2_fxp_mul, s3_fxp_mul, s4_fxp_mul;
	// reg [RESP_DATA_WIDTH-1:0]	out_vec;

	//assign w_add0 = {m0_mult32,64'b0} + {{64{m3_mult32[65]}},m3_mult32[65:0]};
	//assign w_add1 = {{32{m1_mult32[65]}},m1_mult32[65:0],32'b0} + {{32{m2_mult32[65]}},m2_mult32[65:0],32'b0};
	//assign w_s3_d0 = w_add0 + w_add1;
	
	generate
		if(MUL64_ENABLE) begin
			assign w_add0 	= m3_mult32[65:0];
			assign w_add1 	= m1_mult32[65:0] + m2_mult32[65:0];
			assign w_s3_d0 	= w_add0 + {w_add1,32'b0};
		end
		else begin
			assign w_s3_d0 	= 'b0;
		end
	endgenerate

	// 1 cycle (in -> s1)
	operand_select opSelector (
		.clk 	(clk 		),
		.rst  	(rst     	),
		.vec0 	(in_vec0 	),
		.vec1 	(in_vec1 	),
		.valid	(in_valid	),
		.sew  	(in_sew  	),
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
		.out_mult16_p0	(m1_p0		),
		.out_mult16_p1	(m1_p1		),
		.out_mult32		(m1_mult32	)
	);

	mult32 m2 (
		.clk			(clk		),
		.rst 			(rst		),
		.in_a0 			(m2_a0		),
		.in_a1 			(m2_a1		),
		.in_b0 			(m2_b0		),
		.in_b1 			(m2_b1		),
		.out_mult16_p0	(m2_p0		),
		.out_mult16_p1	(m2_p1		),
		.out_mult32		(m2_mult32	)
	);


	mult32 m3 (
		.clk			(clk		),
		.rst			(rst 		),
		.in_a0			(m3_a0		),
		.in_a1			(m3_a1		),
		.in_b0			(m3_b0		),
		.in_b1			(m3_b1		),
		.out_mult16_p0	(m3_p0		),
		.out_mult16_p1	(m3_p1		),
		.out_mult32		(m3_mult32	)
	);


	always @(posedge clk) begin
		if(rst) begin
			s3_b2     	<= 'b0;
			s3_b3     	<= 'b0;
			s3_b4     	<= 'b0;
			s3_b5     	<= 'b0;
			s3_h3     	<= 'b0;
			s3_h2     	<= 'b0;
			s3_h1     	<= 'b0;
			s3_h0     	<= 'b0;
			s3_w1     	<= 'b0;
			s3_w0     	<= 'b0;
			s3_d0     	<= 'b0;

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

			s0_lsb    	<= 'b0;
			s1_lsb    	<= 'b0;
			s2_lsb    	<= 'b0;
			s3_lsb    	<= 'b0;
			s4_lsb    	<= 'b0;

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

			s0_out_addr	<= 'b0;
			s1_out_addr <= 'b0;
			s2_out_addr <= 'b0;
			s3_out_addr <= 'b0;
			s4_out_addr <= 'b0;
			out_addr	<= 'b0;

			// out_vec 	<= 'b0;
		end

		else begin
			s3_b2     	<= m2_p1;
			s3_b3     	<= m2_p0;
			s3_b4     	<= m1_p1;
			s3_b5     	<= m1_p0;

			s3_h3     	<= m0_p0;
			s3_h2     	<= m0_p1;
			s3_h1     	<= m3_p0;
			s3_h0     	<= m3_p1;

			s3_w1     	<= m0_mult32;
			s3_w0     	<= m3_mult32;

			s3_d0     	<= w_s3_d0;

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

			s0_fxp_s    <= in_valid ? in_fxp_s : 'b0;
			s1_fxp_s    <= s0_fxp_s;
			s2_fxp_s    <= s1_fxp_s;
			s3_fxp_s    <= s2_fxp_s;
			s4_fxp_s    <= s3_fxp_s;

			s0_fxp_mul	<= in_valid ? in_fxp_mul : 'b0;
			s1_fxp_mul	<= s0_fxp_mul;
			s2_fxp_mul	<= s1_fxp_mul;
			s3_fxp_mul	<= s2_fxp_mul;
			s4_fxp_mul	<= s3_fxp_mul;

			s0_lsb    	<= (~in_opSel[1] & in_opSel[0] & ~in_widen) & in_valid;
			s1_lsb    	<= s0_lsb;
			s2_lsb    	<= s1_lsb;
			s3_lsb    	<= s2_lsb;
			s4_lsb    	<= s3_lsb;

			s0_out_addr	<= in_valid ? in_addr : 'h0;
			s1_out_addr <= s0_out_addr;
			s2_out_addr <= s1_out_addr;
			s3_out_addr <= s2_out_addr;
			s4_out_addr <= s3_out_addr;
			out_addr	<= s4_out_addr;

			// out_vec 	<= out_vec;
		end
	end

	generate
		if (FXP_ENABLE) begin
			if(MUL64_ENABLE) begin
				always @(posedge clk) begin
					if(rst) begin
						out_vec <= 'b0;
					end 
					else begin
						casex ({s4_fxp_mul, s4_lsb, s4_sew})
							'b0000 : out_vec <= {s3_h3[15:8],s3_h2[15:8],s3_b5[15:8],s3_b4[15:8],s3_b3[15:8],s3_b2[15:8],s3_h1[15:8],s3_h0[15:8]};
							'b0001 : out_vec <= {s3_h3[31:16], s3_h2[31:16], s3_h1[31:16], s3_h0[31:16]};
							'b0010 : out_vec <= {s3_w1[63:32], s3_w0[63:32]};

							'b0100 : out_vec <= {s3_h3[7:0],s3_h2[7:0],s3_b5[7:0],s3_b4[7:0],s3_b3[7:0],s3_b2[7:0],s3_h1[7:0],s3_h0[7:0]};
							'b0101 : out_vec <= {s3_h3[15:0], s3_h2[15:0], s3_h1[15:0], s3_h0[15:0]};
							'b0110 : out_vec <= {s3_w1[31:0], s3_w0[31:0]};
							//'b11:  out_vec <= s4_lsb ? s3_d0[63:0] : s3_d0[127:64];
							'b0?11 : out_vec <= s3_d0;

							// fxp needs middle bits
							'b1?00 : out_vec <= {s3_h3[11:4],s3_h2[11:4],s3_b5[11:4],s3_b4[11:4],s3_b3[11:4],s3_b2[11:4],s3_h1[11:4],s3_h0[11:4]};
							'b1?01 : out_vec <= {s3_h3[23:8], s3_h2[23:8], s3_h1[23:8], s3_h0[23:8]};
							'b1?10 : out_vec <= {s3_w1[47:16], s3_w0[47:16]};

							default: out_vec <= 'h0; // Doesn't exist for ZVE*
						endcase
					end
				end

				always @(posedge clk) begin
					if(rst) begin
						out_vd <= 'b0;
					end 
					else begin
						case ({s4_fxp_mul, s4_fxp_s, s4_sew})
							'b0100 : out_vd	<= {s3_h3[8],s3_h2[8],s3_b5[8],s3_b4[8],s3_b3[8],s3_b2[8],s3_h1[8],s3_h0[8]};
							'b0101 : out_vd	<= {1'b0, s3_h3[16], 1'b0, s3_h2[16], 1'b0, s3_h1[16], 1'b0, s3_h0[16]};
							'b0110 : out_vd <= {3'b0, s3_w1[32], 3'b0, s3_w0[32]};
							//'b11:  out_vd <= s4_lsb ? s3_d0[63:0] : s3_d0[63];
							'b0111 : out_vd <= {7'b0, s3_d0[64]}; // FIXME - how do we find shift out?

							'b1000 : out_vd	<= {s3_h3[3],s3_h2[3],s3_b5[3],s3_b4[3],s3_b3[3],s3_b2[3],s3_h1[3],s3_h0[3]};
							'b1001 : out_vd	<= {1'b0, s3_h3[7], 1'b0, s3_h2[7], 1'b0, s3_h1[7], 1'b0, s3_h0[7]};
							'b1010 : out_vd <= {3'b0, s3_w1[15], 3'b0, s3_w0[15]};

							default: out_vd <= 'h0;
						endcase
					end
				end

				always @(posedge clk) begin
					if(rst) begin
						out_vd1 <= 'b0;
					end 
					else begin
						case ({s4_fxp_mul, s4_fxp_s, s4_sew})
							'b0100 : out_vd1 <= {s3_h3[7],s3_h2[7],s3_b5[7],s3_b4[7],s3_b3[7],s3_b2[7],s3_h1[7],s3_h0[7]};
							'b0101 : out_vd1 <= {1'b0, s3_h3[15], 1'b0, s3_h2[15], 1'b0, s3_h1[15], 1'b0, s3_h0[15]};
							'b0110 : out_vd1 <= {3'b0, s3_w1[31], 3'b0, s3_w0[31]};
							//'b11:  out_vd1 <= s4_lsb ? s3_d0[63:0] : s3_d0[63];
							'b0111 : out_vd1 <= {7'b0, s3_d0[63]}; // FIXME - how do we find shift out?

							'b1000 : out_vd1 <= {s3_h3[3],s3_h2[3],s3_b5[3],s3_b4[3],s3_b3[3],s3_b2[3],s3_h1[3],s3_h0[3]};
							'b1001 : out_vd1 <= {1'b0, s3_h3[7], 1'b0, s3_h2[7], 1'b0, s3_h1[7], 1'b0, s3_h0[7]};
							'b1010 : out_vd1 <= {3'b0, s3_w1[15], 3'b0, s3_w0[15]};

							default: out_vd1 <= 'h0;
						endcase
					end
				end

				always @(posedge clk) begin
					if(rst) begin
						out_vd10 <= 'b0;
					end 
					else begin
						case ({s4_fxp_mul, s4_fxp_s, s4_sew})
							'b0100 : out_vd10 <= {(|s3_h3[7:0]),(|s3_h2[7:0]),(|s3_b5[7:0]),(|s3_b4[7:0]),(|s3_b3[7:0]),(|s3_b2[7:0]),(|s3_h1[7:0]),(|s3_h0[7:0])};
							'b0101 : out_vd10 <= {1'b0, |(s3_h3[15:0]), 1'b0, (|s3_h2[15:0]), 1'b0, (|s3_h1[15:0]), 1'b0, (|s3_h0[15:0])};
							'b0110 : out_vd10 <= {3'b0, (|s3_w1[31:0]), 3'b0, (|s3_w0[31:0])};
							'b0111 : out_vd10 <= {7'b0, (|s3_d0[63:0])}; // FIXME - how do we find shift out?

							'b1000 : out_vd10 <= {s3_h3[3:0],s3_h2[3:0],s3_b5[3:0],s3_b4[3:0],s3_b3[3:0],s3_b2[3:0],s3_h1[3:0],s3_h0[3:0]};
							'b1001 : out_vd10 <= {1'b0, s3_h3[7:0], 1'b0, s3_h2[7:0], 1'b0, s3_h1[7:0], 1'b0, s3_h0[7:0]};
							'b1010 : out_vd10 <= {3'b0, s3_w1[15:0], 3'b0, s3_w0[15:0]};

							default: out_vd10 <= 'h0;
						endcase
					end
				end
			end else begin
				always @(posedge clk) begin
					if(rst) begin
						out_vec <= 'b0;
					end 
					else begin
						casex ({s4_fxp_mul, s4_lsb, s4_sew})
							'b0000 : out_vec <= {s3_h3[15:8],s3_h2[15:8],s3_b5[15:8],s3_b4[15:8],s3_b3[15:8],s3_b2[15:8],s3_h1[15:8],s3_h0[15:8]};
							'b0001 : out_vec <= {s3_h3[31:16], s3_h2[31:16], s3_h1[31:16], s3_h0[31:16]};
							'b0010 : out_vec <= {s3_w1[63:32], s3_w0[63:32]};

							'b0100 : out_vec <= {s3_h3[7:0],s3_h2[7:0],s3_b5[7:0],s3_b4[7:0],s3_b3[7:0],s3_b2[7:0],s3_h1[7:0],s3_h0[7:0]};
							'b0101 : out_vec <= {s3_h3[15:0], s3_h2[15:0], s3_h1[15:0], s3_h0[15:0]};
							'b0110 : out_vec <= {s3_w1[31:0], s3_w0[31:0]};

							// fxp needs middle bits
							'b1?00 : out_vec <= {s3_h3[11:4],s3_h2[11:4],s3_b5[11:4],s3_b4[11:4],s3_b3[11:4],s3_b2[11:4],s3_h1[11:4],s3_h0[11:4]};
							'b1?01 : out_vec <= {s3_h3[23:8], s3_h2[23:8], s3_h1[23:8], s3_h0[23:8]};
							'b1?10 : out_vec <= {s3_w1[47:16], s3_w0[47:16]};

							default: out_vec <= 'h0; // Doesn't exist for ZVE*
						endcase
					end
				end

				always @(posedge clk) begin
					if(rst) begin
						out_vd <= 'b0;
					end 
					else begin
						case ({s4_fxp_mul, s4_fxp_s, s4_sew})
							'b0100 : out_vd	<= {s3_h3[8],s3_h2[8],s3_b5[8],s3_b4[8],s3_b3[8],s3_b2[8],s3_h1[8],s3_h0[8]};
							'b0101 : out_vd	<= {1'b0, s3_h3[16], 1'b0, s3_h2[16], 1'b0, s3_h1[16], 1'b0, s3_h0[16]};
							'b0110 : out_vd <= {3'b0, s3_w1[32], 3'b0, s3_w0[32]};

							'b1000 : out_vd	<= {s3_h3[3],s3_h2[3],s3_b5[3],s3_b4[3],s3_b3[3],s3_b2[3],s3_h1[3],s3_h0[3]};
							'b1001 : out_vd	<= {1'b0, s3_h3[7], 1'b0, s3_h2[7], 1'b0, s3_h1[7], 1'b0, s3_h0[7]};
							'b1010 : out_vd <= {3'b0, s3_w1[15], 3'b0, s3_w0[15]};

							default: out_vd <= 'h0;
						endcase
					end
				end

				always @(posedge clk) begin
					if(rst) begin
						out_vd1 <= 'b0;
					end 
					else begin
						case ({s4_fxp_mul, s4_fxp_s, s4_sew})
							'b0100 : out_vd1 <= {s3_h3[7],s3_h2[7],s3_b5[7],s3_b4[7],s3_b3[7],s3_b2[7],s3_h1[7],s3_h0[7]};
							'b0101 : out_vd1 <= {1'b0, s3_h3[15], 1'b0, s3_h2[15], 1'b0, s3_h1[15], 1'b0, s3_h0[15]};
							'b0110 : out_vd1 <= {3'b0, s3_w1[31], 3'b0, s3_w0[31]};

							'b1000 : out_vd1 <= {s3_h3[3],s3_h2[3],s3_b5[3],s3_b4[3],s3_b3[3],s3_b2[3],s3_h1[3],s3_h0[3]};
							'b1001 : out_vd1 <= {1'b0, s3_h3[7], 1'b0, s3_h2[7], 1'b0, s3_h1[7], 1'b0, s3_h0[7]};
							'b1010 : out_vd1 <= {3'b0, s3_w1[15], 3'b0, s3_w0[15]};

							default: out_vd1 <= 'h0;
						endcase
					end
				end

				always @(posedge clk) begin
					if(rst) begin
						out_vd10 <= 'b0;
					end 
					else begin
						case ({s4_fxp_mul, s4_fxp_s, s4_sew})
							'b0100 : out_vd10 <= {(|s3_h3[7:0]),(|s3_h2[7:0]),(|s3_b5[7:0]),(|s3_b4[7:0]),(|s3_b3[7:0]),(|s3_b2[7:0]),(|s3_h1[7:0]),(|s3_h0[7:0])};
							'b0101 : out_vd10 <= {1'b0, |(s3_h3[15:0]), 1'b0, (|s3_h2[15:0]), 1'b0, (|s3_h1[15:0]), 1'b0, (|s3_h0[15:0])};
							'b0110 : out_vd10 <= {3'b0, (|s3_w1[31:0]), 3'b0, (|s3_w0[31:0])};

							'b1000 : out_vd10 <= {s3_h3[3:0],s3_h2[3:0],s3_b5[3:0],s3_b4[3:0],s3_b3[3:0],s3_b2[3:0],s3_h1[3:0],s3_h0[3:0]};
							'b1001 : out_vd10 <= {1'b0, s3_h3[7:0], 1'b0, s3_h2[7:0], 1'b0, s3_h1[7:0], 1'b0, s3_h0[7:0]};
							'b1010 : out_vd10 <= {3'b0, s3_w1[15:0], 3'b0, s3_w0[15:0]};

							default: out_vd10 <= 'h0;
						endcase
					end
				end
			end
		end else begin
			if(MUL64_ENABLE) begin
				always @(posedge clk) begin
					if(rst) begin
						out_vec <= 'b0;
					end 
					else begin
						case ({s4_lsb, s4_sew})
							'b000 : out_vec <= {s3_h3[15:8],s3_h2[15:8],s3_b5[15:8],s3_b4[15:8],s3_b3[15:8],s3_b2[15:8],s3_h1[15:8],s3_h0[15:8]};
							'b001 : out_vec <= {s3_h3[31:16], s3_h2[31:16], s3_h1[31:16], s3_h0[31:16]};
							'b010 : out_vec <= {s3_w1[63:32], s3_w0[63:32]};

							'b100 : out_vec <= {s3_h3[7:0],s3_h2[7:0],s3_b5[7:0],s3_b4[7:0],s3_b3[7:0],s3_b2[7:0],s3_h1[7:0],s3_h0[7:0]};
							'b101 : out_vec <= {s3_h3[15:0], s3_h2[15:0], s3_h1[15:0], s3_h0[15:0]};
							'b110 : out_vec <= {s3_w1[31:0], s3_w0[31:0]};
							//'b11:  out_vec <= s4_lsb ? s3_d0[63:0] : s3_d0[127:64];
							'b011,
							'b111 : out_vec <= s3_d0;

							default: out_vec <= 'h0;
						endcase
					end
				end

				always @(posedge clk) begin
					out_vd 	<= 'b0;
					out_vd1 <= 'b0;
					out_vd10<= 'b0;
				end
			end else begin
				always @(posedge clk) begin
					if(rst) begin
						out_vec <= 'b0;
					end 
					else begin
						case ({s4_lsb, s4_sew})
							'b000 : out_vec <= {s3_h3[15:8],s3_h2[15:8],s3_b5[15:8],s3_b4[15:8],s3_b3[15:8],s3_b2[15:8],s3_h1[15:8],s3_h0[15:8]};
							'b001 : out_vec <= {s3_h3[31:16], s3_h2[31:16], s3_h1[31:16], s3_h0[31:16]};
							'b010 : out_vec <= {s3_w1[63:32], s3_w0[63:32]};

							'b100 : out_vec <= {s3_h3[7:0],s3_h2[7:0],s3_b5[7:0],s3_b4[7:0],s3_b3[7:0],s3_b2[7:0],s3_h1[7:0],s3_h0[7:0]};
							'b101 : out_vec <= {s3_h3[15:0], s3_h2[15:0], s3_h1[15:0], s3_h0[15:0]};
							'b110 : out_vec <= {s3_w1[31:0], s3_w0[31:0]};
							default : out_vec 	<= 'h0;
						endcase
					end
				end

				always @(posedge clk) begin
					out_vd 	<= 'b0;
					out_vd1 <= 'b0;
					out_vd10<= 'b0;
				end
			end
		end
	endgenerate

	//TODO feed correct 8bit inputs to m's and get the correct output to registers and select the result at the last mux

endmodule