`define MIN(a,b) {(a < b) ? a : b}

module operand_select #(
	parameter INPUT_WIDTH  	= 64,
	parameter OUTPUT_WIDTH 	= 18,
	parameter OPSEL_WIDTH  	= 2,
	parameter SEW_WIDTH    	= 2,
	parameter ENABLE_64_BIT = 1
) (
	input                            		clk,
	input                            		rst,
	input  		signed	[ INPUT_WIDTH-1:0] 	vec0,
	input  		signed	[ INPUT_WIDTH-1:0] 	vec1,
	input         		[ OPSEL_WIDTH-1:0] 	opSel,
	input         		[   SEW_WIDTH-1:0] 	sew,
	input                            		valid,
	output 	reg signed 	[OUTPUT_WIDTH-1:0] 	m0_a0,
	output 	reg signed 	[OUTPUT_WIDTH-1:0] 	m0_b0,
	output 	reg signed 	[OUTPUT_WIDTH-1:0] 	m0_a1,
	output 	reg signed 	[OUTPUT_WIDTH-1:0] 	m0_b1,
	output 	reg signed 	[OUTPUT_WIDTH-1:0] 	m1_a0,
	output 	reg signed 	[OUTPUT_WIDTH-1:0] 	m1_b0,
	output 	reg signed 	[OUTPUT_WIDTH-1:0] 	m1_a1,
	output 	reg signed 	[OUTPUT_WIDTH-1:0] 	m1_b1,
	output 	reg signed 	[OUTPUT_WIDTH-1:0] 	m2_a0,
	output 	reg signed 	[OUTPUT_WIDTH-1:0] 	m2_b0,
	output 	reg signed 	[OUTPUT_WIDTH-1:0] 	m2_a1,
	output 	reg signed 	[OUTPUT_WIDTH-1:0] 	m2_b1,
	output 	reg signed 	[OUTPUT_WIDTH-1:0] 	m3_a0,
	output 	reg signed 	[OUTPUT_WIDTH-1:0] 	m3_b0,
	output 	reg signed 	[OUTPUT_WIDTH-1:0] 	m3_a1,
	output 	reg signed 	[OUTPUT_WIDTH-1:0] 	m3_b1
);

	reg signed	[INPUT_WIDTH-1:0]	r_vec0, r_vec1;
	reg			[OPSEL_WIDTH-1:0] 	r_opSel;
	reg			[SEW_WIDTH-1:0]		r_sew;

	wire		[OUTPUT_WIDTH-1:0] 	a0, a1, a2, a3, b0, b1, b2, b3;
	wire		[OUTPUT_WIDTH-1:0] 	b_a0, b_a1, b_a2, b_a3, b_a4, b_a5, b_a6, b_a7;
	wire		[OUTPUT_WIDTH-1:0] 	b_b0, b_b1, b_b2, b_b3, b_b4, b_b5, b_b6, b_b7;
	
	wire 							a_signed, b_signed;
	wire 							a0_ext, a1_ext, a2_ext, a3_ext;  
	wire 							b0_ext, b1_ext, b2_ext, b3_ext;
	wire 							b_a0_ext, b_a1_ext, b_a2_ext, b_a3_ext, b_a4_ext, b_a5_ext, b_a6_ext, b_a7_ext;
	wire 							b_b0_ext, b_b1_ext, b_b2_ext, b_b3_ext, b_b4_ext, b_b5_ext, b_b6_ext, b_b7_ext;
	wire 							b_op, h_op, w_op, d_op;    

    assign a_signed = ~(r_opSel == 'b00);
    assign b_signed = r_opSel[0];

	assign b_op 	= (r_sew == 'b00);
	assign h_op 	= (r_sew == 'b01);
	assign w_op 	= (r_sew == 'b10);

	assign a0 		= b_op ? 'b0 : {{2{a0_ext}}, r_vec0[15:0]};
	assign a1 		= b_op ? 'b0 : {{2{a1_ext}}, r_vec0[31:16]};
	assign a2 		= b_op ? 'b0 : {{2{a2_ext}}, r_vec0[47:32]};
	assign a3 		= b_op ? 'b0 : {{2{a3_ext}}, r_vec0[63:48]};
	assign b0 		= b_op ? 'b0 : {{2{b0_ext}}, r_vec1[15:0]};
	assign b1 		= b_op ? 'b0 : {{2{b1_ext}}, r_vec1[31:16]};
	assign b2 		= b_op ? 'b0 : {{2{b2_ext}}, r_vec1[47:32]};
	assign b3 		= b_op ? 'b0 : {{2{b3_ext}}, r_vec1[63:48]};

	assign b_a0 	= b_op ? {{10{b_a0_ext}}, r_vec0[7:0]}   : 'b0;
	assign b_a1 	= b_op ? {{10{b_a1_ext}}, r_vec0[15:8]}  : 'b0;
	assign b_a2 	= b_op ? {{10{b_a2_ext}}, r_vec0[23:16]} : 'b0;
	assign b_a3 	= b_op ? {{10{b_a3_ext}}, r_vec0[31:24]} : 'b0;
	assign b_a4 	= b_op ? {{10{b_a4_ext}}, r_vec0[39:32]} : 'b0;
	assign b_a5 	= b_op ? {{10{b_a5_ext}}, r_vec0[47:40]} : 'b0;
	assign b_a6 	= b_op ? {{10{b_a6_ext}}, r_vec0[55:48]} : 'b0;
	assign b_a7 	= b_op ? {{10{b_a7_ext}}, r_vec0[63:56]} : 'b0;

	assign b_b0 	= b_op ? {{10{b_b0_ext}}, r_vec1[7:0]}   : 'b0;
	assign b_b1 	= b_op ? {{10{b_b1_ext}}, r_vec1[15:8]}  : 'b0;
	assign b_b2 	= b_op ? {{10{b_b2_ext}}, r_vec1[23:16]} : 'b0;
	assign b_b3 	= b_op ? {{10{b_b3_ext}}, r_vec1[31:24]} : 'b0;
	assign b_b4 	= b_op ? {{10{b_b4_ext}}, r_vec1[39:32]} : 'b0;
	assign b_b5 	= b_op ? {{10{b_b5_ext}}, r_vec1[47:40]} : 'b0;
	assign b_b6 	= b_op ? {{10{b_b6_ext}}, r_vec1[55:48]} : 'b0;
	assign b_b7 	= b_op ? {{10{b_b7_ext}}, r_vec1[63:56]} : 'b0;

	assign a0_ext 	= a_signed & r_vec0[15] & h_op;
	assign a1_ext 	= a_signed & r_vec0[31] & (h_op | w_op);
	assign a2_ext 	= a_signed & r_vec0[47] & h_op;
	assign a3_ext 	= a_signed & r_vec0[63];

	assign b0_ext 	= b_signed & r_vec1[15] & h_op;
	assign b1_ext 	= b_signed & r_vec1[31] & (h_op | w_op);
	assign b2_ext 	= b_signed & r_vec1[47] & h_op;
	assign b3_ext 	= b_signed & r_vec1[63];

	assign b_a0_ext = a_signed & r_vec0[7]  & b_op;
	assign b_a1_ext = a_signed & r_vec0[15] & b_op;
	assign b_a2_ext = a_signed & r_vec0[23] & b_op;
	assign b_a3_ext = a_signed & r_vec0[31] & b_op;
	assign b_a4_ext = a_signed & r_vec0[39] & b_op;
	assign b_a5_ext = a_signed & r_vec0[47] & b_op;
	assign b_a6_ext = a_signed & r_vec0[55] & b_op;
	assign b_a7_ext = a_signed & r_vec0[63] & b_op;

	assign b_b0_ext = b_signed & r_vec1[7]  & b_op;
	assign b_b1_ext = b_signed & r_vec1[15] & b_op;
	assign b_b2_ext = b_signed & r_vec1[23] & b_op;
	assign b_b3_ext = b_signed & r_vec1[31] & b_op;
	assign b_b4_ext = b_signed & r_vec1[39] & b_op;
	assign b_b5_ext = b_signed & r_vec1[47] & b_op;
	assign b_b6_ext = b_signed & r_vec1[55] & b_op;
	assign b_b7_ext = b_signed & r_vec1[63] & b_op;

	always @(posedge clk) begin
		if(rst) begin
			r_vec0 	<= 'b0;
			r_vec1 	<= 'b0;
			r_sew 	<= 'b0;
			r_opSel <= 'b0;
			m0_a0 	<= 'b0;
			m0_b0 	<= 'b0;
			m0_a1 	<= 'b0;
			m0_b1 	<= 'b0;
			m1_a0 	<= 'b0;
			m1_b0 	<= 'b0;
			m1_a1 	<= 'b0;
			m1_b1 	<= 'b0;
			m2_a0 	<= 'b0;
			m2_b0 	<= 'b0;
			m2_a1 	<= 'b0;
			m2_b1 	<= 'b0;
			m3_a0 	<= 'b0;
			m3_b0 	<= 'b0;
			m3_a1 	<= 'b0;
			m3_b1 	<= 'b0;
		end 
		else begin
			r_vec0 	<= valid ? vec0 : 'h0;
			r_vec1 	<= valid ? vec1 : 'h0;
			if (ENABLE_64_BIT) begin
				r_sew 	<= valid ? sew 	: 'h0;
			end else begin
				r_sew 	<= valid ? `MIN(sew,2'b10) : 'h0;
			end
			r_opSel <= valid ? opSel : 'h0;
			m0_a0 	<= b_op ? b_a7 : a3;
			m0_b0 	<= b_op ? b_b7 : b3;
			m0_a1 	<= b_op ? b_a6 : a2;
			m0_b1 	<= b_op ? b_b6 : b2;
			m1_a0 	<= b_op ? b_a5 : a3;
			m1_b0 	<= b_op ? b_b5 : b1;
			m1_a1 	<= b_op ? b_a4 : a2;
			m1_b1 	<= b_op ? b_b4 : b0;
			m2_a0 	<= b_op ? b_a3 : a1;
			m2_b0 	<= b_op ? b_b3 : b3;
			m2_a1 	<= b_op ? b_a2 : a0;
			m2_b1 	<= b_op ? b_b2 : b2;
			m3_a0 	<= b_op ? b_a1 : a1;
			m3_b0 	<= b_op ? b_b1 : b1;
			m3_a1 	<= b_op ? b_a0 : a0;
			m3_b1 	<= b_op ? b_b0 : b0;
		end
	end

endmodule