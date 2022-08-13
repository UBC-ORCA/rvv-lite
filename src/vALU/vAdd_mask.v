module vAdd_mask #(
	parameter REQ_DATA_WIDTH  	= 64,
	parameter RESP_DATA_WIDTH 	= 64,
	parameter MIN_MAX_ENABLE  	= 1,
	parameter DATA_WIDTH_BITS 	= 6
) (
	input                          	clk,
	input                          	rst,
	input   [ 	REQ_DATA_WIDTH-1:0] in_m0,
	input                          	in_valid,
	input 	[	REQ_DATA_WIDTH-1:0]	in_count,
	output 	[  RESP_DATA_WIDTH-1:0] out_vec
	);

	reg [DATA_WIDTH_BITS-1:0]	s0_add0_next;
	reg [DATA_WIDTH_BITS-1:0]	s0_add0;
	reg [RESP_DATA_WIDTH-1:0] 	s0_count;

	assign out_vec = s0_add0 + s0_count;

	integer i;

	// This may need to be updated
	generate
		always @(*) begin
			s0_add0_next = 0;
			for (i = 0; i < REQ_DATA_WIDTH; i=i+1) begin
				s0_add0_next	= s0_add0_next + in_m0[i];
			end
		end

		always @(posedge clk) begin
			if (rst) begin
				s0_add0 	<= 0;
				s0_count 	<= 0;
			end else begin
				s0_add0 	<= s0_add0_next;

				s0_count 	<= in_count;
			end
		end
	endgenerate

endmodule