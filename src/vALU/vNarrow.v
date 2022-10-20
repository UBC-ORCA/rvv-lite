module vNarrow #(
	parameter REQ_DATA_WIDTH    = 64,
	parameter NARROW_DATA_WIDTH = REQ_DATA_WIDTH>>1,
	parameter RESP_DATA_WIDTH   = 64,
	parameter REQ_ADDR_WIDTH 	= 32,
	parameter OPSEL_WIDTH       = 2 ,
	parameter SEW_WIDTH         = 2 ,
	parameter REQ_BYTE_EN_WIDTH = 8 ,
	parameter ENABLE_64_BIT		= 1
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

	assign s0_64 = in_vec0[31:0];
	assign s0_32 = {in_vec0[47:32],in_vec0[15:0]};
	assign s0_16 = {in_vec0[55:48],in_vec0[39:32],in_vec0[23:16],in_vec0[7:0]};

	always @(posedge clk) begin
		if(rst) begin
			turn  		<= 'b0;
		end else begin
			turn 		<= in_valid & ~turn;
		end
	end

	assign out_be	= turn ? {in_be[6],in_be[4],in_be[2],in_be[0],4'b0} : {4'b0,in_be[6],in_be[4],in_be[2],in_be[0]};
	assign out_valid= in_valid;
	assign out_sew	= in_sew - 2'b01;

	// FIXME - make combinational so turn is in order
	always @(*) begin
		case({turn,s0_sew})
			3'b111: begin
				if (ENABLE_64_BIT) begin
					out_vec = {s0_64,32'b0};
				end else begin
					out_vec = s0_vec0;
				end
			end
			3'b110: 	out_vec = {s0_32,32'b0};
			3'b101: 	out_vec = {s0_16,32'b0};
			3'b011: begin
				if (ENABLE_64_BIT) begin
					out_vec = {32'b0,s0_64};
				end else begin
					out_vec = s0_vec0;
				end
			end
			3'b010: 	out_vec = {32'b0,s0_32};
			3'b001: 	out_vec = {32'b0,s0_16};
			default: 	out_vec = s0_vec0;
		endcase
	end
endmodule