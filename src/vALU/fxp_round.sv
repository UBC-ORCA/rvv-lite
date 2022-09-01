`define BYTE 8

module fxp_round #(
	parameter DATA_WIDTH 	= 64,
	parameter DW_B 			= DATA_WIDTH >> 3
) (
	input 						 clk,
	input 						 rst,
	input 		[			1:0] vxrm, // comes from vfu "round" port
	input 		[	   DW_B-1:0] v_d, // do it like this so we can add directly
	input		[	   DW_B-1:0] v_d1,
	input		[	   DW_B-1:0] v_d10,
	input 		[DATA_WIDTH-1:0] vec_in,
	input						 in_valid,
	output    	[DATA_WIDTH-1:0] vec_out
);

reg [DATA_WIDTH-1:0] r_vec;
reg [DATA_WIDTH-1:0] base_vec;

genvar i;
generate
	for (i = 0; i < DW_B; i=i+1) begin
		always @(posedge clk) begin
			case ({in_valid, vxrm})
				3'b100: 	r_vec[(i<<3)] <= v_d1[i];
				3'b101: 	r_vec[(i<<3)] <= v_d[i] & v_d10[i];
				3'b110: 	r_vec[(i<<3)] <= 1'b0;
				3'b111:		r_vec[(i<<3)] <= ~v_d[i] & v_d10[i];
				default: 	r_vec[(i<<3)] <= 'h0;
			endcase
		end
	end
endgenerate

always @(posedge clk) begin
	if (rst) begin
		base_vec <= 'h0;
	end else begin
		base_vec <= in_valid ? vec_in : 'h0;
	end
end

// doesn't account for overflow, but this shouldn't be a problem because
// asub -> can't average to greater than the max value
// aadd -> can't average to greater than the max value
// ssrl/a -> can't right shift to greater than max value
// smul -> think lol

assign vec_out = base_vec + r_vec;

endmodule

// module rshift (
// 	parameter DATA_WIDTH 	= 64,
// 	parameter DW_B 			= DATA_WIDTH>>3
// ) (
// 	input 						clk,
// 	input 	   [DATA_WIDTH-1:0] vec_in,
// 	input 	   [		   1:0] sew,
// 	input 	   [		   4:0] shift,
// 	input 	   					srl,
// 	output reg [	  DW_B-1:0] v_d,
// 	output reg [	  DW_B-1:0] v_d1,	// v_d and v_d10 are the same for this op
// 	output reg [	  DW_B-1:0] v_d10, 	// v_d and v_d10 are the same for this op
// 	output reg [DATA_WIDTH-1:0] vec_out
// );

// wire [DATA_WIDTH-1:0] vec_out_sew 	[0:3];
// wire [		DW_B-1:0] v_d_sew		[0:3];
// wire [		DW_B-1:0] v_d1_sew		[0:3];
// wire [		DW_B-1:0] v_d1_sew		[0:3];

// wire [DATA_WIDTH-1:0] shift_out		[0:3];
// wire [DATA_WIDTH-1:0] shift_in		[0:3];

// genvar i;
// integer j;

// generate
// 	for (i = 0; i < 4; i = i + 1) begin
// 		always @(*) begin
// 			for (j = 0; j < DW_B >> i; j = j + 1) begin
// 				vec_out_sew	[i][j<<(i+3) +: (1<<(i+3))] = vec_in[j<<(i+3) +: (1<<(i+3))] >> shift;

// 				shift_out 	[i][j<<(i+3) +: (1<<(i+3))] = vec_in[j<<(i+3) +: (1<<(i+3))] << ((1<<(i+3)) - shift);
// 				shift_in 	[i][j<<(i+3) +: (1<<(i+3))] = {DATA_WIDTH{srl ? 1'b0 : vec_in[((j+1)<<(i+3))-1]}} << ((1<<(i+3)) - shift); // bit shift in

// 				v_d_sew 	[i][j<<(i+3) +: (1<<(i+3))] = vec_in[j<<(i+3) + shift];
// 				v_d1_sew	[i][j<<(i+3) +: (1<<(i+3))] = vec_in[j<<(i+3) + (shift - 1)];
// 				v_d10_sew	[i][j<<(i+3) +: (1<<(i+3))] = |shift_out[i][j<<(i+3) +: (1<<(i+3))];
// 			end
// 		end
// 	end

// 	always @(posedge clk) begin
// 		vec_out <=	vec_out_sew[sew] | shift_in[sew];

// 		v_d 	<= 	v_d_sew[sew];
// 		v_d1 	<= 	v_d1_sew[sew];
// 		v_d10 	<= 	v_d10_sew[sew];
// 	end
// endgenerate

// endmodule