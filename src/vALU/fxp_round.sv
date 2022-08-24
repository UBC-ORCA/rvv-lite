module fxp_round #(
	parameter DATA_WIDTH 	= 64,
	parameter DW_B 			= DATA_WIDTH >> 3
) (
	input 					 clk,
	input 					 rst,
	input 	[			1:0] vxrm, // comes from vfu "round" port
	input 	[	   DW_B-1:0] v_d, // do it like this so we can add directly
	input	[	   DW_B-1:0] v_d1,
	input	[	   DW_B-1:0] v_d10,
	input 	[DATA_WIDTH-1:0] vec_in,
	input					 in_valid,
	output 	[DATA_WIDTH-1:0] vec_out
);

wire [DATA_WIDTH-1:0] r_vec;
reg  [		DW_B-1:0] r;

always @(*) begin
	r = 'h0;
	case (vxrm)
		2'b00: 	r = v_d1;
		2'b01: 	r = v_d & v_d10;
		2'b10: 	r = 1'b0;
		2'b11:	r = ~v_d & v_d10;
	endcase
end

genvar i;
generate
	for (i = 0; i < DW_B; i=i+1) begin
		assign r_vec[(i<<3) +: 8] = r[i]; // zero-pad
	end
endgenerate

assign vec_out = in_valid ? vec_in + r_vec : 'h0;

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