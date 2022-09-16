module vNarrow #(
	parameter REQ_DATA_WIDTH    = 64,
	parameter NARROW_DATA_WIDTH = REQ_DATA_WIDTH>>1,
	parameter RESP_DATA_WIDTH   = 64,
	parameter REQ_ADDR_WIDTH 	= 32,
	parameter OPSEL_WIDTH       = 2 ,
	parameter SEW_WIDTH         = 2 ,
	parameter REQ_BYTE_EN_WIDTH = 8
) (
	input                              	clk      ,
	input                              	rst      ,
	input      	[   REQ_DATA_WIDTH-1:0] in_vec0  ,
	input                              	in_valid ,
	input      	[        SEW_WIDTH-1:0] in_sew   ,
	input      	[REQ_BYTE_EN_WIDTH-1:0] in_be    ,
	output    	[REQ_BYTE_EN_WIDTH-1:0] out_be   ,
	output reg	[  RESP_DATA_WIDTH-1:0] out_vec  ,
	output                             	out_valid,
	output     	[				   1:0] out_sew
);

	reg	[   REQ_DATA_WIDTH-1:0]	s0_vec0;
	reg	[REQ_BYTE_EN_WIDTH-1:0] s0_be;
	reg                         s0_valid;
	reg                         turn ;
	reg [        SEW_WIDTH-1:0] s0_sew  ;
	wire [NARROW_DATA_WIDTH-1:0] s0_64, s0_32, s0_16;

	assign s0_64 = s0_vec0[31:0];
	assign s0_32 = {s0_vec0[47:32],s0_vec0[15:0]};
	assign s0_16 = {s0_vec0[55:48],s0_vec0[39:32],s0_vec0[23:16],s0_vec0[7:0]};

	always @(posedge clk) begin
		if(rst) begin
			s0_sew 		<= 'b0;

			s0_vec0  	<= 'b0;

			turn  		<= 'b0;

			s0_be    	<= 'b0;

			s0_valid	<= 'b0;
		end

		else begin
			s0_vec0 	<= in_valid ? in_vec0 : 'h0;

			turn 		<= in_valid & ~turn;

			s0_sew  	<= in_valid ? in_sew : 'h0;

			s0_be  		<= in_valid ? in_be : 'h0;

			s0_valid 	<= in_valid;
		end
	end

	assign out_be	= turn ? {s0_be[6],s0_be[4],s0_be[2],s0_be[0],4'b0} : {4'b0,s0_be[6],s0_be[4],s0_be[2],s0_be[0]};
	assign out_valid= s0_valid;
	assign out_sew	= s0_sew - 2'b01;

	always @(*) begin
		case({turn,s0_sew})
			3'b111: 	out_vec = {s0_64,32'b0};
			3'b110: 	out_vec = {s0_32,32'b0};
			3'b101: 	out_vec = {s0_16,32'b0};
			3'b011: 	out_vec = {32'b0,s0_64};
			3'b010: 	out_vec = {32'b0,s0_32};
			3'b001: 	out_vec = {32'b0,s0_16};
			default: 	out_vec = s0_vec0;
		endcase
	end
endmodule