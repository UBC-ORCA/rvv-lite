module vNarrow #(
	parameter REQ_DATA_WIDTH    = 64,
	parameter RESP_DATA_WIDTH   = 64,
	parameter OPSEL_WIDTH       = 2 ,
	parameter SEW_WIDTH         = 2 ,
	parameter REQ_BYTE_EN_WIDTH = 8
) (
	input                              clk      ,
	input                              rst      ,
	input      [   REQ_DATA_WIDTH-1:0] in_vec0  ,
	input      [   REQ_DATA_WIDTH-1:0] in_vec1  ,
	input                              in_valid ,
	input      [        SEW_WIDTH-1:0] in_sew   ,
	input                              in_turn  ,
	input      [REQ_BYTE_EN_WIDTH-1:0] in_be    ,
	output reg [REQ_BYTE_EN_WIDTH-1:0] out_be   ,
	output reg [  RESP_DATA_WIDTH-1:0] out_vec  ,
	output reg                         out_valid
);

	reg [   REQ_DATA_WIDTH-1:0] s0_vec0, s1_vec0, s2_vec0, s3_vec0, s4_vec0;
	reg [REQ_BYTE_EN_WIDTH-1:0] s0_be, s1_be, s2_be, s3_be, s4_be;
	reg                         s1_valid, s2_valid, s3_valid, s0_valid, s4_valid;
	reg                         s0_turn ;
	reg [        SEW_WIDTH-1:0] s0_sew  ;


	always @(posedge clk) begin
		if(rst) begin
			out_vec   <= 'b0;
			out_valid <= 'b0;
			s0_sew    <= 'b0;

			s0_valid <= 'b0;
			s1_valid <= 'b0;
			s2_valid <= 'b0;
			s3_valid <= 'b0;
			s4_valid <= 'b0;
			s0_vec0  <= 'b0;
			s1_vec0  <= 'b0;
			s2_vec0  <= 'b0;
			s3_vec0  <= 'b0;
			s4_vec0  <= 'b0;
			s0_turn  <= 'b0;
			s0_be    <= 'b0;
			s1_be    <= 'b0;
			s2_be    <= 'b0;
			s3_be    <= 'b0;
			s4_be    <= 'b0;
			out_be   <= 'b0;
		end

		else begin
			s0_vec0 <= {REQ_DATA_WIDTH{in_valid}} & in_vec0;
			s0_turn <= in_valid & in_turn;
			s0_sew  <= {SEW_WIDTH{in_valid}} & in_sew;

			s1_vec0 <= s0_turn 	? (s0_sew[1]	? (s0_sew[0] ? {s0_vec0[31:0],32'b0} : {s0_vec0[47:32],s0_vec0[15:0],32'b0})
												: (s0_sew[0] ? {s0_vec0[55:48],s0_vec0[39:32],s0_vec0[23:16],s0_vec0[7:0],32'b0} : s0_vec0))
								:  (s0_sew[1]	? (s0_sew[0] ? {32'b0,s0_vec0[31:0]} : {32'b0,s0_vec0[47:32],s0_vec0[15:0]})
												: (s0_sew[0] ? {32'b0,s0_vec0[55:48],s0_vec0[39:32],s0_vec0[23:16],s0_vec0[7:0]} : s0_vec0));

			s2_vec0 <= s1_vec0;
			s3_vec0 <= s2_vec0;
			s4_vec0 <= s3_vec0;

			s0_be  <= {REQ_BYTE_EN_WIDTH{in_valid}} & in_be;
			s1_be  <= s0_turn ? {s0_be[6],s0_be[4],s0_be[2],s0_be[0],4'b0} : {4'b0,s0_be[6],s0_be[4],s0_be[2],s0_be[0]};
			s2_be  <= s1_be;
			s3_be  <= s2_be;
			s4_be  <= s3_be;
			out_be <= s4_be;

			s0_valid <= in_valid;
			s1_valid <= s0_valid;
			s2_valid <= s1_valid;
			s3_valid <= s2_valid;
			s4_valid <= s3_valid;

			out_vec   <= s4_vec0;
			out_valid <= s4_valid;
		end
	end


endmodule