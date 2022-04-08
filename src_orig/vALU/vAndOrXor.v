module vAndOrXor #(
	parameter REQ_DATA_WIDTH    = 64,
	parameter RESP_DATA_WIDTH   = 64,
	parameter OPSEL_WIDTH       = 2 
) (
	input                              clk      ,
	input                              rst      ,
	input      [   REQ_DATA_WIDTH-1:0] in_vec0  ,
	input      [   REQ_DATA_WIDTH-1:0] in_vec1  ,
	input                              in_valid ,
	input      [      OPSEL_WIDTH-1:0] in_opSel , //01=and,10=or,11=xor
	output reg [  RESP_DATA_WIDTH-1:0] out_vec  ,
	output reg                         out_valid
);

	reg [ REQ_DATA_WIDTH-1:0] s0_vec0, s0_vec1;
	reg [    OPSEL_WIDTH-1:0] s0_opSel     ;
	reg [RESP_DATA_WIDTH-1:0] s1_out_vec, s2_out_vec, s3_out_vec, s4_out_vec;
	reg                       s1_valid, s2_valid, s3_valid, s0_valid, s4_valid;



	always @(posedge clk) begin
		if(rst) begin
			out_vec   <= 'b0;
			out_valid <= 'b0;
			s1_out_vec <= 'b0;
			s2_out_vec <= 'b0;
            s3_out_vec <= 'b0;
            s4_out_vec <= 'b0;
            s0_valid <= 'b0;
            s1_valid <= 'b0;
            s2_valid <= 'b0;
            s3_valid <= 'b0;
            s4_valid <= 'b0;
            s0_vec0    <= 'b0;
			s0_vec1    <= 'b0;
			s0_opSel   <= 'b0;
		end
		
		else begin
			case(s0_opSel)
				2'b01 : s1_out_vec <= s0_vec0 & s0_vec1;
				2'b10 : s1_out_vec <= s0_vec0 | s0_vec1;
				2'b11 : s1_out_vec <= s0_vec0 ^ s0_vec1;
				2'b00 : s1_out_vec <= 'b0;
			endcase
			s0_vec0    <= {REQ_DATA_WIDTH{in_valid}} & in_vec0;
			s0_vec1    <= {REQ_DATA_WIDTH{in_valid}} & in_vec1;
			s0_opSel   <= {OPSEL_WIDTH{in_valid}} & in_opSel;
			s2_out_vec <= s1_out_vec;
			s3_out_vec <= s2_out_vec;
			s4_out_vec <= s3_out_vec;
			out_vec <= s4_out_vec;
			s0_valid <= in_valid;
			s1_valid <= s0_valid;
			s2_valid <= s1_valid;
			s3_valid <= s2_valid;
			s4_valid <= s3_valid;
			out_valid <= s4_valid;
        end
	end


endmodule