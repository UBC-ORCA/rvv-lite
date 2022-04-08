module vPopc #(
	parameter REQ_DATA_WIDTH  = 8,
	parameter RESP_DATA_WIDTH = 8,
	parameter SEW_WIDTH       = 2,
	parameter OPSEL_WIDTH     = 3,
	parameter MIN_MAX_ENABLE  = 1
) (
	input                            clk,
	input                            rst,
	input      [ REQ_DATA_WIDTH-1:0] in_m0,
	input                            in_valid,
	input      [      SEW_WIDTH-1:0] in_sew,
	input 							 in_start,
	input 							 in_end,
	output reg [RESP_DATA_WIDTH-1:0] out_vec,
	output reg						 out_valid
	);

	reg [63:0] count;
	wire [63:0] w_count;
	wire [7:0] w_s1_mask;
 	reg [7:0] s0_mask, s1_mask;
	reg s0_end, s1_end, s2_end, s3_end, s4_end;
	reg [SEW_WIDTH-1:0] s0_sew;

	assign w_s1_mask = s0_sew[1] 	? (s0_sew[0] 	? {7'b0,s0_mask[0]} 
													: {6'b0,s0_mask[4],s0_mask[0]}) 
									: (s0_sew[0] 	? {4'b0,s0_mask[6],s0_mask[4],s0_mask[2],s0_mask[0]} 
													: s0_mask);

	vAdd_mask vAdd_mask0 (
		.clk   (clk      ),
		.rst   (rst      ),
		.in_m0  (s1_mask  ),
		.in_count(count),
		.out_vec(w_count)
	);

	always @(posedge clk) begin
		if(rst) begin
			s0_mask <= 'b0;
			s0_sew <= 'b0;
			s1_mask <= 'b0;
			count <= 'b0;
			out_vec <= 'b0;
			out_valid <= 'b0;
			s0_end <= 'b0;
			s1_end <= 'b0;
			s2_end <= 'b0;
			s3_end <= 'b0;
			s4_end <= 'b0;
		end

		else begin
			s0_mask <= in_m0 & {8{in_valid}};
			s0_sew <= in_sew;
			s1_mask <= w_s1_mask;
			count <= s4_end ? 'b0 : w_count;
			out_vec <= s4_end ? count : 'b0;
			out_valid <= s4_end;
			s0_end <= in_end;
			s1_end <= s0_end;
			s2_end <= s1_end;
			s3_end <= s2_end;
			s4_end <= s3_end;
		end
	end

endmodule