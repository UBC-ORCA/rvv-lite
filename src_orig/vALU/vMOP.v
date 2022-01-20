module vMOP #(
	parameter REQ_DATA_WIDTH  = 64,
	parameter RESP_DATA_WIDTH = 64,
	parameter SEW_WIDTH       = 2,
	parameter OPSEL_WIDTH     = 3,
	parameter MIN_MAX_ENABLE  = 1
) (
	input                            clk,
	input                            rst,
	input      [ REQ_DATA_WIDTH-1:0] in_m0,
	input      [ REQ_DATA_WIDTH-1:0] in_m1,
	input                            in_valid,
	input      [    OPSEL_WIDTH-1:0] in_opSel,
	output reg [RESP_DATA_WIDTH-1:0] out_vec,
	output reg                       out_valid
);

	genvar i;

	reg s0_valid, s1_valid, s2_valid, s3_valid, s4_valid;
	reg [OPSEL_WIDTH-1:0] s0_opSel;
	reg [REQ_DATA_WIDTH-1:0] s0_m0, s0_m1;
	reg [RESP_DATA_WIDTH-1:0] s1_out_vec, s2_out_vec, s3_out_vec, s4_out_vec;


	always @(posedge clk) begin
		if(rst) begin
			s0_m0 <= 'b0;
			s0_m1 <= 'b0;
			s0_opSel <= 'b0;
			s1_out_vec <= 'b0;
			s2_out_vec <= 'b0;
			s3_out_vec <= 'b0;
			s4_out_vec <= 'b0;
			out_vec    <= 'b0;
			out_valid  <= 'b0;
			s0_valid <= 'b0;
			s1_valid <= 'b0;
			s2_valid <= 'b0;
			s3_valid <= 'b0;
			s4_valid <= 'b0;
		end

		else begin
			s0_m0 <= in_m0 & {REQ_DATA_WIDTH{in_valid}};
			s0_m1 <= in_m1 & {REQ_DATA_WIDTH{in_valid}};
			s0_opSel <= in_opSel & {OPSEL_WIDTH{in_valid}};
			s0_valid <= in_valid;
			s1_valid <= s0_valid;
			s2_valid <= s1_valid;
			s3_valid <= s2_valid;
			s4_valid <= s3_valid;
			case(s0_opSel)
				3'b000: s1_out_vec <= s0_m0 & s0_m1;
				3'b001: s1_out_vec <= ~s0_m0 & ~s0_m1;
				3'b010: s1_out_vec <= ~(s0_m0 & s0_m1);
				3'b011: s1_out_vec <= s0_m0 ^ s0_m1;
				3'b100: s1_out_vec <= s0_m0 | s0_m1;
				3'b101: s1_out_vec <= ~s0_m0 | ~s0_m1;
				3'b110: s1_out_vec <= ~(s0_m0 | s0_m1);
				3'b111: s1_out_vec <= ~(s0_m0 ^ s0_m1);
			endcase
			s2_out_vec <= s1_out_vec;
			s3_out_vec <= s2_out_vec;
			s4_out_vec <= s3_out_vec;
			out_vec <= s4_out_vec;
			out_valid  <= s4_valid;
		end
	end

endmodule