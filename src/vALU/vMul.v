`include "mult32.v"
`include "operand_selector.v"

module vMul #(
	parameter REQ_DATA_WIDTH  	= 64,
	parameter RESP_DATA_WIDTH 	= 64,
	parameter REQ_ADDR_WIDTH 	= 32,
	parameter SEW_WIDTH       	= 2 ,
	parameter OPSEL_WIDTH     	= 2 , 
	parameter MUL64_ENABLE    	= 0
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
	output reg 	[RESP_DATA_WIDTH-1:0] 	out_vec,
	output reg                       	out_valid,
	output reg 	[ REQ_ADDR_WIDTH-1:0] 	out_addr
);

	//Wires
	wire signed [17:0]	m0_a0, m0_b0, m0_a1, m0_b1, m1_a0, m1_b0, m1_a1, m1_b1, m2_a0, m2_b0, m2_a1, m2_b1, m3_a0, m3_b0, m3_a1, m3_b1;
	wire signed [33:0] 	m0_p0, m0_p1, m1_p0, m1_p1, m2_p0, m2_p1, m3_p0, m3_p1;
	wire signed [66:0] 	m0_mult32, m1_mult32, m2_mult32, m3_mult32;

	//wire signed [133:0] w_s2_d0;
	//wire signed [131:0] w_add0;
	//wire signed [131:0] w_add1;

	wire signed [70:0] 	w_s2_d0;
	wire signed [70:0] 	w_add0;
	wire signed [70:0] 	w_add1;

	//Registers
	reg signed [17:0] 	s2_b5, s2_b4, s2_b3, s2_b2;

	reg signed [32:0] 	s2_h0, s2_h1, s2_h2, s2_h3;

	reg signed [66:0] 	s2_w0, s2_w1;

	//reg signed [133:0] s2_d0;
	reg signed[70:0] 	s2_d0;

	reg 						s0_valid, s1_valid, s2_valid, s3_valid, s4_valid;
	reg [REQ_ADDR_WIDTH-1:0]	s0_out_addr, s1_out_addr, s2_out_addr, s3_out_addr, s4_out_addr;
	reg [	  SEW_WIDTH-1:0]	s0_sew, s1_sew, s2_sew, s3_sew, s4_sew;
	reg                 		s0_lsb, s1_lsb, s2_lsb, s3_lsb, s4_lsb;

	//assign w_add0 = {m0_mult32,64'b0} + {{64{m3_mult32[65]}},m3_mult32[65:0]};
	//assign w_add1 = {{32{m1_mult32[65]}},m1_mult32[65:0],32'b0} + {{32{m2_mult32[65]}},m2_mult32[65:0],32'b0};
	//assign w_s2_d0 = w_add0 + w_add1;
	
	generate
		if(MUL64_ENABLE) begin
			assign w_add0 	= m3_mult32[65:0];
			assign w_add1 	= m1_mult32[65:0] + m2_mult32[65:0];
			assign w_s2_d0 	= w_add0 + {w_add1,32'b0};
		end
		else begin
			assign w_s2_d0 	= 'b0;
		end
	endgenerate

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
			s2_b2     	<= 'b0;
			s2_b3     	<= 'b0;
			s2_b4     	<= 'b0;
			s2_b5     	<= 'b0;
			s2_h3     	<= 'b0;
			s2_h2     	<= 'b0;
			s2_h1     	<= 'b0;
			s2_h0     	<= 'b0;
			s2_w1     	<= 'b0;
			s2_w0     	<= 'b0;
			s2_d0     	<= 'b0;

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

			s0_out_addr	<= 'b0;
			s1_out_addr <= 'b0;
			s2_out_addr <= 'b0;
			s3_out_addr <= 'b0;
			s4_out_addr <= 'b0;
			out_addr	<= 'b0;
		end

		else begin
			s2_b2     	<= m2_p1;
			s2_b3     	<= m2_p0;
			s2_b4     	<= m1_p1;
			s2_b5     	<= m1_p0;

			s2_h3     	<= m0_p0;
			s2_h2     	<= m0_p1;
			s2_h1     	<= m3_p0;
			s2_h0     	<= m3_p1;

			s2_w1     	<= m0_mult32;
			s2_w0     	<= m3_mult32;

			s2_d0     	<= w_s2_d0;

			s0_valid  	<= in_valid;
			s1_valid  	<= s0_valid;
			s2_valid  	<= s1_valid;
			s3_valid  	<= s2_valid;
			s4_valid  	<= s3_valid;
			out_valid 	<= s4_valid;

			s0_sew    	<= {SEW_WIDTH{in_valid}} & in_sew;
			s1_sew    	<= s0_sew;
			s2_sew    	<= s1_sew;
			s3_sew    	<= s2_sew;
			s4_sew    	<= s3_sew;

			s0_lsb    	<= (~in_opSel[1] & in_opSel[0] & ~in_widen) & in_valid;
			s1_lsb    	<= s0_lsb;
			s2_lsb    	<= s1_lsb;
			s3_lsb    	<= s2_lsb;
			s4_lsb    	<= s3_lsb;

			s0_out_addr	<= {REQ_ADDR_WIDTH{in_valid}} & in_addr;
			s1_out_addr <= s0_out_addr;
			s2_out_addr <= s1_out_addr;
			s3_out_addr <= s2_out_addr;
			s4_out_addr <= s3_out_addr;
			out_addr	<= s4_out_addr;
		end
	end

	generate
		if(MUL64_ENABLE) begin
			always @(posedge clk) begin
				if(rst) begin
					out_vec <= 'b0;
				end 
				else begin
					case (s4_sew)
						'b00 : out_vec	<= s4_lsb ? {s2_h3[7:0],s2_h2[7:0],s2_b5[7:0],s2_b4[7:0],s2_b3[7:0],s2_b2[7:0],s2_h1[7:0],s2_h0[7:0]}
													:  {s2_h3[15:8],s2_h2[15:8],s2_b5[15:8],s2_b4[15:8],s2_b3[15:8],s2_b2[15:8],s2_h1[15:8],s2_h0[15:8]};
						'b01 : out_vec	<= s4_lsb ? {s2_h3[15:0], s2_h2[15:0], s2_h1[15:0], s2_h0[15:0]} 
													: {s2_h3[31:16], s2_h2[31:16], s2_h1[31:16], s2_h0[31:16]};
						'b10 : out_vec 	<= s4_lsb ? {s2_w1[31:0], s2_w0[31:0]} 
													: {s2_w1[63:32], s2_w0[63:32]};
						//'b11:  out_vec <= s4_lsb ? s2_d0[63:0] : s2_d0[127:64];
						'b11 : out_vec 	<= s2_d0;
					endcase
				end
			end
		end

		else begin
			always @(posedge clk) begin
				if(rst) begin
					out_vec <= 'b0;
				end 
				else begin
					case (s4_sew)
						'b00 : out_vec 	<= s4_lsb ? {s2_h3[7:0],s2_h2[7:0],s2_b5[7:0],s2_b4[7:0],s2_b3[7:0],s2_b2[7:0],s2_h1[7:0],s2_h0[7:0]}
								:  {s2_h3[15:8],s2_h2[15:8],s2_b5[15:8],s2_b4[15:8],s2_b3[15:8],s2_b2[15:8],s2_h1[15:8],s2_h0[15:8]};
						'b01 : out_vec 	<= s4_lsb ? {s2_h3[15:0], s2_h2[15:0], s2_h1[15:0], s2_h0[15:0]} 
								: {s2_h3[31:16], s2_h2[31:16], s2_h1[31:16], s2_h0[31:16]};
						'b10 : out_vec 	<= s4_lsb ? {s2_w1[31:0], s2_w0[31:0]} 
								: {s2_w1[63:32], s2_w0[63:32]};
						//'b11:  out_vec <= s4_lsb ? s2_d0[63:0] : s2_d0[127:64];
						'b11 : out_vec 	<= 'b0;
					endcase
				end
			end
		end
	endgenerate

	//TODO feed correct 8bit inputs to m's and get the correct output to registers and select the result at the last mux

endmodule