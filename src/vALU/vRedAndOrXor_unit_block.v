module vRedAndOrXor_unit_block #(
	parameter REQ_DATA_WIDTH	= 32,
	parameter RESP_DATA_WIDTH   = 32,
	parameter OPSEL_WIDTH       = 2,
	parameter ENABLE_64_BIT		= 0
) (
	input 								clk,
	input 								rst,
	input      	[2*REQ_DATA_WIDTH-1:0]	in_vec0,
	input                              	in_en,
	input      	[     OPSEL_WIDTH-1:0] 	in_opSel, //01=and,10=or,11=xor
	output reg	[ RESP_DATA_WIDTH-1:0] 	out_vec 
);
	
	wire [RESP_DATA_WIDTH-1:0] w_vec;

	if (ENABLE_64_BIT | REQ_DATA_WIDTH < 64) begin
		assign w_vec = in_opSel[1] 	? (in_opSel[0] 	? (in_vec0[REQ_DATA_WIDTH-1:0] ^ in_vec0[REQ_DATA_WIDTH*2-1:REQ_DATA_WIDTH])
													: (in_vec0[REQ_DATA_WIDTH-1:0] | in_vec0[REQ_DATA_WIDTH*2-1:REQ_DATA_WIDTH])) 
									: (in_opSel[0] 	? (in_vec0[REQ_DATA_WIDTH-1:0] & in_vec0[REQ_DATA_WIDTH*2-1:REQ_DATA_WIDTH])
													: 'b0);
	end else begin
		assign w_vec = {32'b0,		(in_opSel[1] 	? (in_opSel[0] 	? (in_vec0[31:0] ^ in_vec0[91:64])
																	: (in_vec0[31:0] | in_vec0[91:64])) 
													: (in_opSel[0] 	? (in_vec0[31:0] & in_vec0[91:64])
																	: 'b0))};
	end

	always @(posedge clk) begin
		if (rst) begin
			out_vec <= 0;
		end else begin
			out_vec	<= in_en ? w_vec : in_vec0;
		end
	end
endmodule