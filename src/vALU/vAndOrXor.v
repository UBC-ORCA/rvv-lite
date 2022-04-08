module vAndOrXor #(
	parameter REQ_DATA_WIDTH    = 64,
	parameter RESP_DATA_WIDTH   = 64,
	parameter REQ_ADDR_WIDTH 	= 32,
	parameter OPSEL_WIDTH       = 2
) (
	input                              	clk     ,
	input                              	rst     ,
	input		[	REQ_ADDR_WIDTH-1:0] in_addr	,
	input      	[	REQ_DATA_WIDTH-1:0] in_vec0 ,
	input      	[	REQ_DATA_WIDTH-1:0] in_vec1 ,
	input                              	in_valid,
	input      	[	OPSEL_WIDTH-1:0] 	in_opSel, //01=and,10=or,11=xor
	output reg 	[	RESP_DATA_WIDTH-1:0] out_vec,
	output reg                         	out_valid,
	output reg 	[	REQ_ADDR_WIDTH-1:0] out_addr,
);

	reg [ REQ_DATA_WIDTH-1:0] s0_vec0, s0_vec1;
	reg [    OPSEL_WIDTH-1:0] s0_opSel;
	reg [RESP_DATA_WIDTH-1:0] s1_out_vec, s2_out_vec, s3_out_vec, s4_out_vec;
	reg                       s0_valid, s1_valid, s2_valid, s3_valid, s4_valid;
	reg [ REQ_ADDR_WIDTH-1:0] s0_out_addr, s1_out_addr, s2_out_addr, s3_out_addr, s4_out_addr;

	always @(posedge clk) begin
		if(rst) begin
			s0_vec0    	<= 'b0;
			s0_vec1    	<= 'b0;
			s0_opSel   	<= 'b0;
			s1_out_vec 	<= 'b0;
			s2_out_vec 	<= 'b0;
			s3_out_vec 	<= 'b0;
			s4_out_vec 	<= 'b0;
			out_vec   	<= 'b0;

			s0_valid 	<= 'b0;
			s1_valid 	<= 'b0;
			s2_valid 	<= 'b0;
			s3_valid 	<= 'b0;
			s4_valid 	<= 'b0;
			out_valid 	<= 'b0;

			s0_out_addr <= 'b0;
			s1_out_addr <= 'b0;
			s2_out_addr <= 'b0;
			s3_out_addr <= 'b0;
			s4_out_addr <= 'b0;
			out_addr 	<= 'b0;
		end

		else begin
			case(s0_opSel)
				2'b01 : s1_out_vec <= s0_vec0 & s0_vec1;
				2'b10 : s1_out_vec <= s0_vec0 | s0_vec1;
				2'b11 : s1_out_vec <= s0_vec0 ^ s0_vec1;
				2'b00 : s1_out_vec <= 'b0;
			endcase
			s0_vec0    	<= {REQ_DATA_WIDTH{in_valid}} & in_vec0;
			s0_vec1    	<= {REQ_DATA_WIDTH{in_valid}} & in_vec1;
			s0_opSel   	<= {OPSEL_WIDTH{in_valid}} & in_opSel;
			s2_out_vec 	<= s1_out_vec;
			s3_out_vec 	<= s2_out_vec;
			s4_out_vec 	<= s3_out_vec;
			out_vec 	<= s4_out_vec;

			s0_valid 	<= in_valid;
			s1_valid 	<= s0_valid;
			s2_valid 	<= s1_valid;
			s3_valid 	<= s2_valid;
			s4_valid 	<= s3_valid;
			out_valid 	<= s4_valid;

			s0_out_addr <= {REQ_ADDR_WIDTH{in_valid}} & in_addr;
			s1_out_addr <= s0_out_addr;
			s2_out_addr <= s1_out_addr;
			s3_out_addr <= s2_out_addr;
			s4_out_addr <= s3_out_addr;
			out_addr 	<= s4_out_addr;
		end
	end


endmodule