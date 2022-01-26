module vMerge #(
	parameter REQ_DATA_WIDTH  = 64,
	parameter RESP_DATA_WIDTH = 64,
	parameter SEW_WIDTH       = 2,
	parameter OPSEL_WIDTH     = 3,
	parameter MIN_MAX_ENABLE  = 1,
	parameter MASK_WIDTH      = 8
) (
	input                            clk,
	input                            rst,
	input      [     MASK_WIDTH-1:0] in_mask,
	input      [ REQ_DATA_WIDTH-1:0] in_vec0,
	input      [ REQ_DATA_WIDTH-1:0] in_vec1,
	input                            in_valid,
	output reg [RESP_DATA_WIDTH-1:0] out_vec,
	output reg                       out_valid
);

	genvar i;

	reg                       s0_valid;
	reg                       s1_valid;
	reg                       s2_valid;
	reg                       s3_valid;
	reg                       s4_valid;
	reg [ MASK_WIDTH-1:0] s0_mask;
	reg [ REQ_DATA_WIDTH-1:0] s0_vec0;
	reg [ REQ_DATA_WIDTH-1:0] s0_vec1;
	reg [RESP_DATA_WIDTH-1:0] s1_out_vec;
	reg [RESP_DATA_WIDTH-1:0] s2_out_vec;
	reg [RESP_DATA_WIDTH-1:0] s3_out_vec;
	reg [RESP_DATA_WIDTH-1:0] s4_out_vec;

	wire [RESP_DATA_WIDTH-1:0] w_s1_out_vec;

	for(i=0;i<8;i=i+1) begin
		assign w_s1_out_vec[i*8+7:i*8] = s0_mask ? s0_vec1[i*8+7:i*8] : s0_vec0[i*8+7:i*8];
	end

	always @(posedge clk) begin
		if(rst) begin
			s0_mask <= 'b0;
			s0_vec0      <= 'b0;
			s0_vec1      <= 'b0;
			s1_out_vec <= 'b0;
			s2_out_vec <= 'b0;
			s3_out_vec <= 'b0;
			s4_out_vec <= 'b0;
			out_vec    <= 'b0;
			out_valid  <= 'b0;
			s0_valid   <= 'b0;
			s1_valid   <= 'b0;
			s2_valid   <= 'b0;
			s3_valid   <= 'b0;
			s4_valid   <= s3_valid;
		end

		else begin
			s0_mask <= in_mask;
			s0_vec0    <= in_vec0 & {REQ_DATA_WIDTH{in_valid}};
			s0_vec1    <= in_vec1 & {REQ_DATA_WIDTH{in_valid}};
			s0_valid <= in_valid;
			s1_valid <= s0_valid;
			s2_valid <= s1_valid;
			s3_valid <= s2_valid;
			s4_valid <= s3_valid;
			s1_out_vec <= w_s1_out_vec; 
			s2_out_vec <= s1_out_vec;
			s3_out_vec <= s2_out_vec;
			s4_out_vec <= s3_out_vec;
			out_vec    <= s4_out_vec;
			out_valid  <= s4_valid;
		end
	end

endmodule