module vMCmp #(
	parameter REQ_DATA_WIDTH  	= 64,
	parameter REQ_BYTE_EN_WIDTH = REQ_DATA_WIDTH/8,
	parameter RESP_DATA_WIDTH 	= 64,
	parameter REQ_ADDR_WIDTH 	= 32,
	parameter SEW_WIDTH       	= 2,
	parameter OPSEL_WIDTH     	= 3,
	parameter MIN_MAX_ENABLE  	= 1
) (
	input                            	clk,
	input                            	rst,
	input 	   [   REQ_ADDR_WIDTH-1:0] 	in_addr,
	input      [   REQ_DATA_WIDTH-1:0] 	in_vec0,
	input      [   REQ_DATA_WIDTH-1:0] 	in_vec1,
	input      [                  2:0] 	in_sew,
	input      [                  2:0] 	in_start_idx,
	input                            	in_valid,
	input      [      OPSEL_WIDTH-1:0] 	in_opSel,
	output reg [   REQ_ADDR_WIDTH-1:0] 	out_addr,
	output reg [  RESP_DATA_WIDTH-1:0] 	out_vec,
	output reg [REQ_BYTE_EN_WIDTH-1:0]	out_be,
	output reg                       	out_valid
);

	genvar i, j;

	reg 						s0_valid, s1_valid, s2_valid, s3_valid, s4_valid;
	reg [	 OPSEL_WIDTH-1:0] 	s0_opSel;
	reg [ 	   SEW_WIDTH-1:0]	s0_sew;
	reg [    		     2:0]	s0_start_idx;
	reg [ REQ_DATA_WIDTH-1:0] 	s0_vec0, s0_vec1;
	reg [RESP_DATA_WIDTH-1:0] 	s1_out_vec, s2_out_vec, s3_out_vec, s4_out_vec;
	reg [RESP_DATA_WIDTH-1:0] 	s1_out_be, s2_out_be, s3_out_be, s4_out_be;
	reg [ REQ_ADDR_WIDTH-1:0] 	s0_out_addr, s1_out_addr, s2_out_addr, s3_out_addr, s4_out_addr;

	wire [RESP_DATA_WIDTH-1:0] 	lt_u	[0:3];
	wire [RESP_DATA_WIDTH-1:0]	lt_s	[0:3];
	wire [RESP_DATA_WIDTH-1:0]	eq 		[0:3];
	wire [RESP_DATA_WIDTH-1:0]	be 		[0:3];

	// reg [REQ_BYTE_EN_WIDTH-1:0] val1[0:3], val2 [0:3];

	generate
		for (j = 0; j < 4; j = j + 1) begin
            for (i = 0; i < REQ_BYTE_EN_WIDTH>>j; i = i + 1) begin
            	// assign val1 = s0_vec0[((i+1)<<(j+3))-1:i<<(j+3)]

				assign lt_u[j][i] = (s0_vec0[((i+1)<<(j+3))-1:i<<(j+3)] < s0_vec1[((i+1)<<(j+3))-1:i<<(j+3)]);

				// FIXME is representation sign and magnitude or 2's comp? This changes rep
				assign lt_s[j][i] = (s0_vec0[((i+1)<<(j+3))-1] > s0_vec1[((i+1)<<(j+3))-1]) | 
										((s0_vec0[((i+1)<<(j+3))-1] === s0_vec1[((i+1)<<(j+3))-1]) &
										(s0_vec0[((i+1)<<(j+3))-2:i<<(j+3)] < s0_vec1[((i+1)<<(j+3))-2:i<<(j+3)]));

				assign eq[j][i] = (s0_vec0[((i+1)<<(j+3))-1:i<<(j+3)] === s0_vec1[((i+1)<<(j+3))-1:i<<(j+3)]);

				assign be[j][i] = s0_valid;	// set bits to 0 if input is invalid!!!
			end
		end
	endgenerate

	// TODO will have to update be_out for writeback since it will be a multi-cycle read/write but we have to write to the same register each time!!!!
	// ok actually how about instead we latch the value until the index we reach is the end of the vector? maybe?

	always @(posedge clk) begin
		if(rst) begin
			s0_vec0		<= 'b0;
			s0_vec1		<= 'b0;
			s0_opSel 	<= 'b0;
			s0_sew 		<= 'b0;
			s1_out_vec 	<= 'b0;
			s2_out_vec 	<= 'b0;
			s3_out_vec 	<= 'b0;
			s4_out_vec 	<= 'b0;
			out_vec    	<= 'b0;

			s0_valid 	<= 'b0;
			s1_valid 	<= 'b0;
			s2_valid 	<= 'b0;
			s3_valid 	<= 'b0;
			s4_valid 	<= 'b0;
			out_valid  	<= 'b0;

			s0_out_addr	<= 'b0;
			s1_out_addr	<= 'b0;
			s2_out_addr	<= 'b0;
			s3_out_addr	<= 'b0;
			s4_out_addr	<= 'b0;
			out_addr  	<= 'b0;
		end

		else begin
			s0_vec0 	<= in_vec0 	& {REQ_DATA_WIDTH{in_valid}};
			s0_vec1 	<= in_vec1 	& {REQ_DATA_WIDTH{in_valid}};
			s0_opSel 	<= in_opSel & {OPSEL_WIDTH{in_valid}};
			s0_sew 		<= in_sew 	& {SEW_WIDTH{in_valid}};
			s0_start_idx <= in_start_idx & {3{in_valid}};

			if (s0_valid) begin
				case(s0_opSel)
					3'b000: s1_out_vec 	<=   eq[s0_sew] << s0_start_idx;
					3'b001: s1_out_vec 	<=  ~eq[s0_sew] << s0_start_idx;
					3'b010: s1_out_vec 	<=   lt_u[s0_sew] << s0_start_idx;
					3'b011: s1_out_vec 	<=   lt_s[s0_sew] << s0_start_idx;
					3'b100: s1_out_vec 	<=  (lt_u[s0_sew] | eq[s0_sew]) << s0_start_idx;
					3'b101: s1_out_vec 	<=  (lt_s[s0_sew] | eq[s0_sew]) << s0_start_idx;
					3'b110: s1_out_vec 	<= ~(lt_u[s0_sew] | eq[s0_sew]) << s0_start_idx;
					3'b111: s1_out_vec 	<= ~(lt_s[s0_sew] | eq[s0_sew]) << s0_start_idx;
				endcase
			end
			s2_out_vec 	<= s1_out_vec;
			s3_out_vec 	<= s2_out_vec;
			s4_out_vec 	<= s3_out_vec;
			out_vec 	<= s4_out_vec;
			
			s0_valid 	<= in_valid;
			s1_valid 	<= s0_valid;
			s2_valid 	<= s1_valid;
			s3_valid 	<= s2_valid;
			s4_valid 	<= s3_valid;
			out_valid  	<= s4_valid;

			s0_out_addr	<= {REQ_ADDR_WIDTH{in_valid}} & in_addr;
			s1_out_addr	<= s0_out_addr;
			s2_out_addr	<= s1_out_addr;
			s3_out_addr	<= s2_out_addr;
			s4_out_addr	<= s3_out_addr;
			out_addr  	<= s4_out_addr;

			s1_out_be 	<= be[s0_sew] << s0_start_idx;
			s2_out_be 	<= s1_out_be;
			s3_out_be 	<= s2_out_be;
			s4_out_be 	<= s3_out_be;
			out_be  	<= s4_out_be;
		end
	end

endmodule