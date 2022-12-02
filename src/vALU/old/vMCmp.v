// `include "vMinMaxSelector.v"

module vMCmp #(
	parameter REQ_DATA_WIDTH  	= 64,
	parameter REQ_BYTE_EN_WIDTH = REQ_DATA_WIDTH/8,
	parameter RESP_DATA_WIDTH 	= 64,
	parameter REQ_ADDR_WIDTH 	= 32,
	parameter SEW_WIDTH       	= 2,
	parameter OPSEL_WIDTH     	= 3
) (
	input                            	clk,
	input                            	rst,
	input 	   [   REQ_ADDR_WIDTH-1:0] 	in_addr,
	input      [   REQ_DATA_WIDTH-1:0] 	in_vec0,
	input      [   REQ_DATA_WIDTH-1:0] 	in_vec1,
	input      [        SEW_WIDTH-1:0] 	in_sew,
	input      [                  7:0] 	in_start_idx,
	input                            	in_valid,
	input      [      OPSEL_WIDTH-1:0] 	in_opSel,
	input 								in_req_start,
	input 								in_req_end,
	output reg [   REQ_ADDR_WIDTH-1:0] 	out_addr,
	output reg [  RESP_DATA_WIDTH-1:0] 	out_vec,
	output reg [REQ_BYTE_EN_WIDTH-1:0]	out_be,
	output reg                       	out_valid
);

	genvar i, j;

	reg 						s0_valid, s1_valid, s2_valid, s3_valid, s4_valid;
	reg 						s0_req_end, s1_req_end, s2_req_end;
	reg 						s0_req_start, s1_req_start;
	reg [	 OPSEL_WIDTH-1:0] 	s0_opSel;
	reg [ 	   SEW_WIDTH-1:0]	s0_sew;
	reg [    		     2:0]	s0_start_idx, s1_start_idx; // cheat the system and only use the bottom 3 bits lol
	reg [ REQ_DATA_WIDTH-1:0] 	s0_vec0, s0_vec1;
	reg [RESP_DATA_WIDTH-1:0] 	s1_out_vec, s2_out_vec, s3_out_vec, s4_out_vec;
	reg [REQ_BYTE_EN_WIDTH-1:0] s2_out_be, s3_out_be, s4_out_be;
	reg [ REQ_ADDR_WIDTH-1:0] 	s0_out_addr, s1_out_addr, s2_out_addr, s3_out_addr, s4_out_addr;

	wire [RESP_DATA_WIDTH-1:0] 		lt_u	[0:3];
	wire [RESP_DATA_WIDTH-1:0]		lt_s	[0:3];
	wire [RESP_DATA_WIDTH-1:0]		eq 		[0:3];

	generate
		for (j = 0; j < 4; j = j + 1) begin
            for (i = 0; i < REQ_BYTE_EN_WIDTH>>j; i = i + 1) begin

				assign lt_u[j][i] = (s0_vec0[((i+1)<<(j+3))-1:i<<(j+3)] < s0_vec1[((i+1)<<(j+3))-1:i<<(j+3)]);

				assign lt_s[j][i] = (s0_vec0[((i+1)<<(j+3))-1] > s0_vec1[((i+1)<<(j+3))-1]) | 
										((s0_vec0[((i+1)<<(j+3))-1] == s0_vec1[((i+1)<<(j+3))-1]) &
										(s0_vec0[((i+1)<<(j+3))-2:i<<(j+3)] < s0_vec1[((i+1)<<(j+3))-2:i<<(j+3)]));

				assign eq[j][i] = (s0_vec0[((i+1)<<(j+3))-1:i<<(j+3)] == s0_vec1[((i+1)<<(j+3))-1:i<<(j+3)]);
			end
		end
	endgenerate

	// vMinMaxSelector #(.REQ_DATA_WIDTH(REQ_DATA_WIDTH),.RESP_DATA_WIDTH(RESP_DATA_WIDTH),.SEW_WIDTH(SEW_WIDTH),.OPSEL_WIDTH(OPSEL_WIDTH));

	always @(posedge clk) begin
		if(rst) begin
			s0_vec0			<= 'b0;
			s0_vec1			<= 'b0;
			s0_opSel 		<= 'b0;
			s0_sew 			<= 'b0;
			s1_out_vec 		<= 'b0;
			s2_out_vec 		<= 'b0;
			s3_out_vec 		<= 'b0;
			s4_out_vec 		<= 'b0;
			out_vec    		<= 'b0;

			s0_start_idx 	<= 'b0;
			s1_start_idx 	<= 'b0;

			s0_valid 		<= 'b0;
			s1_valid 		<= 'b0;
			s2_valid 		<= 'b0;
			s3_valid 		<= 'b0;
			s4_valid 		<= 'b0;
			out_valid  		<= 'b0;

			s0_out_addr		<= 'b0;
			s1_out_addr		<= 'b0;
			s2_out_addr		<= 'b0;
			s3_out_addr		<= 'b0;
			s4_out_addr		<= 'b0;
			out_addr  		<= 'b0;

			s2_out_be 		<= 'b0;
		end

		else begin
			s0_vec0 		<= in_valid ? in_vec0 		: 'h0; // & {REQ_DATA_WIDTH{in_valid}};
			s0_vec1 		<= in_valid ? in_vec1 		: 'h0; // & {REQ_DATA_WIDTH{in_valid}};
			s0_opSel 		<= in_valid ? in_opSel 		: 'h0; // & {OPSEL_WIDTH{in_valid}};
			s0_sew 			<= in_valid ? in_sew 		: 'h0; // & {SEW_WIDTH{in_valid}};
			s0_req_end		<= in_valid ? in_req_end 	: 'h0; // & in_valid;
			s0_req_start 	<= in_valid ? in_req_start 	: 'h0; // & in_valid;

			s0_start_idx 	<= in_valid ? in_start_idx 	: 'h0; // & {3{in_valid}};
			s1_start_idx 	<= s0_start_idx;

			s1_req_end		<= s0_req_end;
			s1_req_start 	<= s0_req_start;

			s2_req_end		<= s1_req_end;

			if (s0_valid) begin
				case(s0_opSel)
					3'b000: s1_out_vec 	<=   eq[s0_sew];
					3'b001: s1_out_vec 	<=  ~eq[s0_sew];
					3'b010: s1_out_vec 	<=   lt_u[s0_sew];
					3'b011: s1_out_vec 	<=   lt_s[s0_sew];
					3'b100: s1_out_vec 	<=  (lt_u[s0_sew] | eq[s0_sew]);
					3'b101: s1_out_vec 	<=  (lt_s[s0_sew] | eq[s0_sew]);
					3'b110: s1_out_vec 	<= ~(lt_u[s0_sew] | eq[s0_sew]);
					3'b111: s1_out_vec 	<= ~(lt_s[s0_sew] | eq[s0_sew]);
				endcase
			end
			s2_out_vec 	<= (s1_start_idx == 0 | s1_req_end) ? (s1_out_vec << s1_start_idx) : (s1_out_vec << s1_start_idx) | s2_out_vec;
			s3_out_vec 	<= s2_out_vec;
			s4_out_vec 	<= s3_out_vec;
			out_vec 	<= s4_out_vec;
			
			s0_valid 	<= in_valid;
			s1_valid 	<= s0_valid;
			s2_valid 	<= s1_valid & ((s0_start_idx == 0) | s1_req_end);
			s3_valid 	<= s2_valid;
			s4_valid 	<= s3_valid;
			out_valid  	<= s4_valid;

			s0_out_addr	<= in_valid ? in_addr : 'h0; //{REQ_ADDR_WIDTH{in_valid}} & in_addr;
			s1_out_addr	<= s0_out_addr;
			s2_out_addr	<= s1_out_addr;
			s3_out_addr	<= s2_out_addr;
			s4_out_addr	<= s3_out_addr;
			out_addr  	<= s4_out_addr;

			// circular shift
			s2_out_be 	<= s1_req_start ? 	1 :
											((s1_start_idx == 0 | s2_req_end) ? {s2_out_be[REQ_BYTE_EN_WIDTH-2:0],s2_out_be[REQ_BYTE_EN_WIDTH-1]} : s2_out_be);
			s3_out_be 	<= s2_valid ? s2_out_be : 'h0; // ugh
			s4_out_be 	<= s3_out_be;
			out_be  	<= s4_out_be;
		end
	end

endmodule