module vMinMaxSelector #(
	parameter REQ_DATA_WIDTH  	= 64,
	parameter RESP_DATA_WIDTH 	= 64,
	parameter SEW_WIDTH       	= 2,
	parameter REQ_BE_WIDTH      = REQ_DATA_WIDTH/8,
	parameter ENABLE_64_BIT		= 0
) (
	input  [ REQ_DATA_WIDTH-1:0] 	vec0,
	input  [ REQ_DATA_WIDTH-1:0] 	vec1,
	input  [REQ_DATA_WIDTH+16:0] 	sub_result,
	input  [      SEW_WIDTH-1:0] 	sew,
	input   					 	minMax_sel,
	output [RESP_DATA_WIDTH-1:0] 	minMax_result,
	output [   REQ_BE_WIDTH-1:0] 	equal,
	output [   REQ_BE_WIDTH-1:0] 	lt
);

	genvar i;

	wire [REQ_BE_WIDTH-1:0] 	sgn_bits8;
	wire [REQ_BE_WIDTH-1:0] 	sgn_bits16;
	wire [REQ_BE_WIDTH-1:0] 	sgn_bits32;
	wire [REQ_BE_WIDTH-1:0] 	sgn_bits64;
	wire [REQ_BE_WIDTH-1:0] 	sgn_bits;
	wire [REQ_BE_WIDTH-1:0] 	lt8;
	wire [REQ_BE_WIDTH-1:0] 	lt16;
	wire [REQ_BE_WIDTH-1:0] 	lt32;
	wire [REQ_BE_WIDTH-1:0] 	lt64;
	wire [REQ_BE_WIDTH-1:0] 	equal8;
	wire [REQ_BE_WIDTH-1:0] 	equal16;
	wire [REQ_BE_WIDTH-1:0] 	equal32;
	wire [REQ_BE_WIDTH-1:0] 	equal64;

	assign sgn_bits8 	= {sub_result[79],sub_result[69],sub_result[59],sub_result[49],sub_result[39],sub_result[29],sub_result[19],sub_result[9] };
	assign sgn_bits16	= {sub_result[79],sub_result[79],sub_result[59],sub_result[59],sub_result[39],sub_result[39],sub_result[19],sub_result[19]};
	assign sgn_bits32	= {sub_result[79],sub_result[79],sub_result[79],sub_result[79],sub_result[39],sub_result[39],sub_result[39],sub_result[39]};
	if (ENABLE_64_BIT) begin
		assign sgn_bits64	= {sub_result[79],sub_result[79],sub_result[79],sub_result[79],sub_result[79],sub_result[79],sub_result[79],sub_result[79]};
	end else begin
		assign sgn_bits64	= 'h0;
	end

	assign lt8 			= {sub_result[79],sub_result[69],sub_result[59],sub_result[49],sub_result[39],sub_result[29],sub_result[19],sub_result[9] };
	assign lt16			= {4'b0,sub_result[79],sub_result[59],sub_result[39],sub_result[19]};
	assign lt32			= {6'b0,sub_result[79],sub_result[39]};
	if (ENABLE_64_BIT) begin
		assign lt64		= {7'b0,sub_result[79]};
	end else begin
		assign lt64		= 'h0;
	end

	for(i=0;i<8;i=i+1) begin
		assign minMax_result[8*i+7:8*i] = (sgn_bits[i] ^ minMax_sel) ? vec0[8*i+7:8*i]   : vec1[8*i+7:8*i];
		assign equal8[i] 				= (sub_result[10*i+9:10*i+1] == 'b0);
	end

	assign equal16 	= {4'b0,{equal8[7] & equal8[6]},{equal8[5] & equal8[4]},{equal8[3] & equal8[2]},{equal8[1] & equal8[0]}};
	assign equal32 	= {6'b0,{equal8[7] & equal8[6] & equal8[5] & equal8[4]},{equal8[3] & equal8[2] & equal8[1] & equal8[0]}};
	if (ENABLE_64_BIT) begin
		assign equal64 	= {{equal8[7] & equal8[6] & equal8[5] & equal8[4] & equal8[3] & equal8[2] & equal8[1] & equal8[0]}};
	end else begin
		assign equal64	= 'h0;
	end

	if (ENABLE_64_BIT) begin
		assign sgn_bits = sew[1] ? (sew[0] ? sgn_bits64 : sgn_bits32) : (sew[0] ? sgn_bits16 : sgn_bits8);

		assign equal 	= sew[1] ? (sew[0] ? equal64 : equal32): (sew[0] ? equal16 : equal8);

		assign lt 		= sew[1] ? (sew[0] ? lt64 : lt32) : (sew[0] ? lt16 : lt8);	
	end else begin
		assign sgn_bits = sew[1] ? sgn_bits32 : (sew[0] ? sgn_bits16 : sgn_bits8);

		assign equal 	= sew[1] ? equal32: (sew[0] ? equal16 : equal8);

		assign lt 		= sew[1] ? lt32 : (sew[0] ? lt16 : lt8);	
	end

endmodule