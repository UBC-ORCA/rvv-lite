module vFirst_bit #(
	parameter REQ_DATA_WIDTH  	= 64,
	parameter RESP_DATA_WIDTH 	= 64,
	parameter DATA_WIDTH_BITS 	= 6,
	parameter IDX_BITS 			= 10
) (
	input                          	clk,
	input                          	rst,
	input   [ 	REQ_DATA_WIDTH-1:0] in_m0,
	input                          	in_valid,
	input   [         IDX_BITS-1:0] in_idx,
	output 	[  RESP_DATA_WIDTH-1:0] out_vec,
	output 							out_found
	);

	reg [		IDX_BITS-1:0]	s0_idx_next;
	reg [		IDX_BITS-1:0]	s0_idx_base;
	reg [		IDX_BITS-1:0]	s0_idx;

	reg 						s0_found;
	reg 						found_one_nxt;

	assign out_vec 	= s0_idx + s0_idx_base;
	assign out_found= s0_found;

	integer i;

	// What if we did this in smaller chunks and piped through min/max instead?

	// This may need to be updated
	generate
		always @(*) begin
			s0_idx_next 	= 0;
			found_one_nxt	= 0;
			for (i = 0; i < REQ_DATA_WIDTH; i=i+1) begin
				s0_idx_next		= (in_m0[i] & (~found_one_nxt | i < s0_idx_next)) ? i : s0_idx_next;
				found_one_nxt 	= in_m0[i] | found_one_nxt;
			end
		end

		always @(posedge clk) begin
			if (rst) begin
				s0_idx  	<= 0;
				s0_idx_base <= 0;
			end else begin
				s0_idx_base <= in_valid ? in_idx 		: 'h0;
				s0_idx  	<= in_valid ? s0_idx_next 	: 'h0;

				s0_found	<= in_valid ? found_one_nxt : 'h0;
			end
		end
	endgenerate

endmodule