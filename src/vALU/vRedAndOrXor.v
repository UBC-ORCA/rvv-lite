module vRedAndOrXor #(
	parameter REQ_DATA_WIDTH    = 64,
	parameter RESP_DATA_WIDTH   = 64,
	parameter OPSEL_WIDTH       = 2,
	parameter SEW_WIDTH         = 2 
) (
	input                              clk      ,
	input                              rst      ,
	input      [   REQ_DATA_WIDTH-1:0] in_vec0  ,
	input      [   REQ_DATA_WIDTH-1:0] in_vec1  ,
	input                              in_valid ,
	input							   in_start ,
	input                              in_end,
	input      [      OPSEL_WIDTH-1:0] in_opSel , //01=and,10=or,11=xor
	input      [        SEW_WIDTH-1:0] in_sew	,
	output reg [  RESP_DATA_WIDTH-1:0] out_vec  ,
	output reg                         out_valid
);

	
	reg [REQ_DATA_WIDTH-1:0] s0_vec0;
	reg [OPSEL_WIDTH-1:0] s0_opSel, s1_opSel, s2_opSel, s3_opSel;
	reg [SEW_WIDTH-1:0] s0_sew, s1_sew, s2_sew, s3_sew;
	reg s0_start, s1_start, s2_start, s3_start;
	reg s0_end, s1_end, s2_end, s3_end, s4_end;

	wire [REQ_DATA_WIDTH-1:0] s1_out, s2_out, s3_out, s4_out;


	vRedAndOrXor_unit_block # (
		.REQ_DATA_WIDTH(32)
	) b32 (
		.clk(clk),
		.rst(rst),
		.in_vec0(s0_vec0),
		.in_en(s0_sew < 2'b11),
		.in_opSel(s0_opSel),
		.out_vec(s1_out)
	);
	

	vRedAndOrXor_unit_block # (
		.REQ_DATA_WIDTH(16)
	) b16 (
		.clk(clk),
		.rst(rst),
		.in_vec0(s1_out),
		.in_en(s1_sew < 2'b10),
		.in_opSel(s1_opSel),
		.out_vec(s2_out)
	);


	vRedAndOrXor_unit_block # (
		.REQ_DATA_WIDTH(8)
	) b8 (
		.clk(clk),
		.rst(rst),
		.in_vec0(s2_out),
		.in_en(s2_sew < 2'b01),
		.in_opSel(s2_opSel),
		.out_vec(s3_out)
	);


	vRedAndOrXor_unit_block # (
		.REQ_DATA_WIDTH(64)
	) b64 (
		.clk(clk),
		.rst(rst),
		.in_vec0({s3_out,s4_out}),
		.in_en(~s3_start),
		.in_opSel(s3_opSel),
		.out_vec(s4_out)
	);

	always @(posedge clk) begin
		if(rst) begin
			s0_vec0 <= 'b0;
			s0_opSel <= 'b0;
			s1_opSel <= 'b0;
			s2_opSel <= 'b0;
			s3_opSel <= 'b0;
			s0_sew <= 'b0;
			s1_sew <= 'b0;
			s2_sew <= 'b0;
			s3_sew <= 'b0;
			s0_start <= 'b0;
			s1_start <= 'b0;
			s2_start <= 'b0;
			s3_start <= 'b0;
			s0_end <= 'b0;
			s1_end <= 'b0;
			s2_end <= 'b0;
			s3_end <= 'b0;
			s4_end <= 'b0;
			out_vec <= 'b0;
			out_valid <= 'b0;
		end 
		else begin
			s0_vec0 <= in_vec0 & {REQ_DATA_WIDTH{in_valid}};
			s0_opSel <= in_opSel & {OPSEL_WIDTH{in_valid}};
			s1_opSel <= s0_opSel;
			s2_opSel <= s1_opSel;
			s3_opSel <= s2_opSel;
			s0_sew <= in_sew & {SEW_WIDTH{in_valid}};
			s1_sew <= s0_sew;
			s2_sew <= s1_sew;
			s3_sew <= s2_sew;
			s0_start <= in_start & in_valid;
			s1_start <= s0_start;
			s2_start <= s1_start;
			s3_start <= s2_start;
			s0_end <= in_end & in_valid;
			s1_end <= s0_end;
			s2_end <= s1_end;
			s3_end <= s2_end;
			s4_end <= s3_end;
			out_vec <= s4_end ? s4_out : 'b0;
			out_valid <= s4_end;
		end
	end

endmodule