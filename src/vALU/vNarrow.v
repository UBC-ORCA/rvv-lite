module vNarrow #(
	parameter REQ_DATA_WIDTH    = 64,
	parameter NARROW_DATA_WIDTH = REQ_DATA_WIDTH/2,
	parameter RESP_DATA_WIDTH   = 64,
	parameter REQ_ADDR_WIDTH 	= 32,
	parameter OPSEL_WIDTH       = 2 ,
	parameter SEW_WIDTH         = 2 ,
	parameter REQ_BYTE_EN_WIDTH = 8
) (
	input                              	clk      ,
	input                              	rst      ,
	input      	[   REQ_DATA_WIDTH-1:0] in_vec0  ,
	input      	[ 	REQ_DATA_WIDTH-1:0] in_vec1  ,
	input                              	in_valid ,
	input      	[        SEW_WIDTH-1:0] in_sew   ,
	input                              	in_turn  ,
	input      	[REQ_BYTE_EN_WIDTH-1:0] in_be    ,
	input 		[   REQ_ADDR_WIDTH-1:0] in_addr,
	output reg	[REQ_BYTE_EN_WIDTH-1:0] out_be   ,
	output reg	[  RESP_DATA_WIDTH-1:0] out_vec  ,
	output reg	[   REQ_ADDR_WIDTH-1:0] out_addr,
	output reg                         	out_valid
);

	reg	[   REQ_DATA_WIDTH-1:0]	s0_vec0, s1_vec0, s2_vec0, s3_vec0, s4_vec0;
	reg	[REQ_BYTE_EN_WIDTH-1:0] s0_be, s1_be, s2_be, s3_be, s4_be;
	reg                         s1_valid, s2_valid, s3_valid, s0_valid, s4_valid;
	reg [ REQ_ADDR_WIDTH-1:0] 	s0_out_addr, s1_out_addr, s2_out_addr, s3_out_addr, s4_out_addr;
	reg                         s0_turn ;
	reg [        SEW_WIDTH-1:0] s0_sew  ;
	wire [NARROW_DATA_WIDTH-1:0] s0_64, s0_32, s0_16;

	// FIXME - generalize
	assign s0_64 = s0_vec0[31:0];
	assign s0_32 = {s0_vec0[47:32],s0_vec0[15:0]};
	assign s0_16 = {s0_vec0[55:48],s0_vec0[39:32],s0_vec0[23:16],s0_vec0[7:0]};

	always @(posedge clk) begin
		if(rst) begin
			s0_sew 		<= 'b0;

			s0_valid 	<= 'b0;
			s1_valid 	<= 'b0;
			s2_valid 	<= 'b0;
			s3_valid 	<= 'b0;
			s4_valid 	<= 'b0;
			out_valid 	<= 'b0;

			s0_vec0  	<= 'b0;
			s1_vec0  	<= 'b0;
			s2_vec0  	<= 'b0;
			s3_vec0  	<= 'b0;
			s4_vec0  	<= 'b0;
			out_vec   	<= 'b0;

			s0_out_addr	<= 'b0;
			s1_out_addr <= 'b0;
			s2_out_addr <= 'b0;
			s3_out_addr <= 'b0;
			s4_out_addr <= 'b0;
			out_addr   	<= 'b0;

			s0_turn  	<= 'b0;

			s0_be    	<= 'b0;
			s1_be    	<= 'b0;
			s2_be    	<= 'b0;
			s3_be    	<= 'b0;
			s4_be    	<= 'b0;
			out_be   	<= 'b0;
		end

		else begin
			s0_vec0 	<= in_valid ? in_vec0 : 'h0;
			s0_turn 	<= in_valid & in_turn;
			s0_sew  	<= in_valid ? in_sew : 'h0;

			case({s0_turn,s0_sew})
				3'b111: 	s1_vec0 <= {s0_64,32'b0};
				3'b110: 	s1_vec0 <= {s0_32,32'b0};
				3'b101: 	s1_vec0 <= {s0_16,32'b0};
				3'b011: 	s1_vec0 <= {32'b0,s0_64};
				3'b010: 	s1_vec0 <= {32'b0,s0_32};
				3'b001: 	s1_vec0 <= {32'b0,s0_16};
				default: 	s1_vec0 <= s0_vec0;
			endcase

			// s1_vec0 	<= s0_turn 	? (s0_sew[1]	? (s0_sew[0] ? {s0_vec0[31:0],32'b0} : {s0_vec0[47:32],s0_vec0[15:0],32'b0})
			// 	: (s0_sew[0] ? {s0_vec0[55:48],s0_vec0[39:32],s0_vec0[23:16],s0_vec0[7:0],32'b0} : s0_vec0))
			// :  (s0_sew[1]	? (s0_sew[0] ? {32'b0,s0_vec0[31:0]} : {32'b0,s0_vec0[47:32],s0_vec0[15:0]})
			// 	: (s0_sew[0] ? {32'b0,s0_vec0[55:48],s0_vec0[39:32],s0_vec0[23:16],s0_vec0[7:0]} : s0_vec0));
			s2_vec0 	<= s1_vec0;
			s3_vec0 	<= s2_vec0;
			s4_vec0 	<= s3_vec0;
			out_vec   	<= s4_vec0;

			s0_be  		<= in_valid ? in_be : 'h0;
			s1_be  		<= s0_turn ? {s0_be[6],s0_be[4],s0_be[2],s0_be[0],4'b0} : {4'b0,s0_be[6],s0_be[4],s0_be[2],s0_be[0]};
			s2_be  		<= s1_be;
			s3_be  		<= s2_be;
			s4_be  		<= s3_be;
			out_be 		<= s4_be;

			s0_valid 	<= in_valid;
			s1_valid 	<= s0_valid;
			s2_valid 	<= s1_valid;
			s3_valid 	<= s2_valid;
			s4_valid 	<= s3_valid;
			out_valid 	<= s4_valid;

			s0_out_addr <= in_valid ? in_addr : 'h0;
			s1_out_addr <= s0_out_addr;
			s2_out_addr <= s1_out_addr;
			s3_out_addr <= s2_out_addr;
			s4_out_addr <= s3_out_addr;
			out_addr 	<= s4_out_addr;
		end
	end
endmodule