module vMinMaxSelector #(
	parameter REQ_DATA_WIDTH  = 64,
	parameter RESP_DATA_WIDTH = 64,
	parameter SEW_WIDTH       = 2,
	parameter OPSEL_WIDTH     = 9,
	parameter MIN_MAX_ENABLE  = 1,
	parameter MASK_WIDTH      = 8
) (
	input                        clk,
	input                        rst,
	input  [ REQ_DATA_WIDTH-1:0] vec0,
	input  [ REQ_DATA_WIDTH-1:0] vec1,
	input  [REQ_DATA_WIDTH+16:0] sub_result,
	input  [      SEW_WIDTH-1:0] sew,
	input  [    OPSEL_WIDTH-1:0] minMax_sel,
	output [RESP_DATA_WIDTH-1:0] minMax_result,
	output [     MASK_WIDTH-1:0] equal,
	output [     MASK_WIDTH-1:0] gt,
	output [     MASK_WIDTH-1:0] lt
);

	genvar i;

	wire [MASK_WIDTH-1:0] sgn_bits8;
	wire [MASK_WIDTH-1:0] sgn_bits16;
	wire [MASK_WIDTH-1:0] sgn_bits32;
	wire [MASK_WIDTH-1:0] sgn_bits64;
	wire [MASK_WIDTH-1:0] sgn_bits;
	wire [MASK_WIDTH-1:0] equal8;
	wire [MASK_WIDTH-1:0] equal16;
	wire [MASK_WIDTH-1:0] equal32;
	wire [MASK_WIDTH-1:0] equal64;

	assign sgn_bits8  = {sub_result[79],sub_result[69],sub_result[59],sub_result[49],sub_result[39],sub_result[29],sub_result[19],sub_result[9] };
	assign sgn_bits16 = {sub_result[79],sub_result[79],sub_result[59],sub_result[59],sub_result[39],sub_result[39],sub_result[19],sub_result[19]};
	assign sgn_bits32 = {sub_result[79],sub_result[79],sub_result[79],sub_result[79],sub_result[39],sub_result[39],sub_result[39],sub_result[39]};
	assign sgn_bits64 = {sub_result[79],sub_result[79],sub_result[79],sub_result[79],sub_result[79],sub_result[79],sub_result[79],sub_result[79]};

	assign sgn_bits = sew[1] ? (sew[0] ? sgn_bits64 : sgn_bits32) : (sew[0] ? sgn_bits16 : sgn_bits8);

	for(i=0;i<8;i=i+1) begin
		assign minMax_result[8*i+7:8*i] = (sgn_bits[i] ^ minMax_sel) ? vec0[8*i+7:8*i]   : vec1[8*i+7:8*i];
		assign equal8[i] = (sub_result[10*i+9:10*i+1] == 'b0);
	end

	assign equal16 = {{2{equal8[7] & equal8[6]}},{2{equal8[5] & equal8[4]}},{2{equal8[3] & equal8[2]}},{2{equal8[1] & equal8[0]}}};
	assign equal32 = {{4{equal8[7] & equal8[6] & equal8[5] & equal8[4]}},{4{equal8[3] & equal8[2] & equal8[1] & equal8[0]}}};
	assign equal64 = {{8{equal8[7] & equal8[6] & equal8[5] & equal8[4] & equal8[3] & equal8[2] & equal8[1] & equal8[0]}}};

	assign equal = sew[1] ? (sew[0] ? equal64 : equal32): (sew[0] ? equal16 : equal8);

	assign lt = sgn_bits;
	assign gt = ~sgn_bits;

endmodule