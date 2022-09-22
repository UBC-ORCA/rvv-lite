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
				default: 	r_vec[(i<<3)] <= 1'b0;
			endcase
		end
	end
endgenerate

always @(posedge clk) begin
	if (rst) begin
		base_vec <= 'h0;
	end else begin
		base_vec <= vec_in;
	end
end

// doesn't account for overflow, but this shouldn't be a problem because
// asub -> can't average to greater than the max value
// aadd -> can't average to greater than the max value
// ssrl/a -> can't right shift to greater than max value
// smul -> think lol

assign vec_out = base_vec + r_vec;

endmodule