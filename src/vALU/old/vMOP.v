module vMOP #(
	parameter REQ_DATA_WIDTH  	= 64,
	parameter RESP_DATA_WIDTH 	= 64,
	parameter REQ_ADDR_WIDTH 	= 32,
	parameter OPSEL_WIDTH     	= 3,
	parameter MIN_MAX_ENABLE  	= 1
) (
	input                            clk,
	input                            rst,
	input 	   [ REQ_ADDR_WIDTH-1:0] in_addr,
	input      [ REQ_DATA_WIDTH-1:0] in_m0,
	input      [ REQ_DATA_WIDTH-1:0] in_m1,
	input                            in_valid,
	input      [    OPSEL_WIDTH-1:0] in_opSel,
	output reg [ REQ_ADDR_WIDTH-1:0] out_addr,
	output reg [RESP_DATA_WIDTH-1:0] out_vec,
	output reg                       out_valid
);

	genvar i;

	reg 						s0_valid, s1_valid, s2_valid, s3_valid, s4_valid;
	reg [	 OPSEL_WIDTH-1:0] 	s0_opSel;
	reg [ REQ_DATA_WIDTH-1:0] 	s0_m0, s0_m1;
	reg [RESP_DATA_WIDTH-1:0] 	s1_out_vec, s2_out_vec, s3_out_vec, s4_out_vec;
	reg [ REQ_ADDR_WIDTH-1:0] 	s0_out_addr, s1_out_addr, s2_out_addr, s3_out_addr, s4_out_addr;

	always @(posedge clk) begin
		if(rst) begin
			s0_m0 		<= 'b0;
			s0_m1 		<= 'b0;
			s0_opSel 	<= 'b0;
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
			s0_m0 		<= in_valid ? in_m0 	: 'h0;
			s0_m1 		<= in_valid ? in_m1 	: 'h0;
			s0_opSel 	<= in_valid ? in_opSel 	: 'h0;

			case(s0_opSel)
				3'b000: s1_out_vec 	<= s0_m0 & ~s0_m1;
				3'b001: s1_out_vec 	<= s0_m0 & s0_m1;
				3'b010: s1_out_vec 	<= s0_m0 | s0_m1;
				3'b011: s1_out_vec 	<= s0_m0 ^ s0_m1;
				3'b100: s1_out_vec 	<= s0_m0 | ~s0_m1;
				3'b101: s1_out_vec 	<= ~(s0_m0 & s0_m1);
				3'b110: s1_out_vec 	<= ~(s0_m0 | s0_m1);
				3'b111: s1_out_vec 	<= ~(s0_m0 ^ s0_m1);
			endcase
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

			s0_out_addr	<= in_valid ? in_addr : 'h0;
			s1_out_addr	<= s0_out_addr;
			s2_out_addr	<= s1_out_addr;
			s3_out_addr	<= s2_out_addr;
			s4_out_addr	<= s3_out_addr;
			out_addr  	<= s4_out_addr;
		end
	end

endmodule