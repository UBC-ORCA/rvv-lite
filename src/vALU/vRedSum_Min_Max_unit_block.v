// `include "vMinMaxSelector.v"
// `include "vAdd_unit_block.v"

module vRedSum_min_max_unit_block #(
	parameter REQ_DATA_WIDTH  	= 32,
	parameter RESP_DATA_WIDTH 	= 64,
	parameter OPSEL_WIDTH     	= 2 ,
	parameter SEW_WIDTH       	= 2 ,
	parameter MIN_MAX_ENABLE  	= 1
) (
	input                             clk,
	input                             rst,
	input      [REQ_DATA_WIDTH*2-1:0] vec0,
	input                             en,
	input      [       SEW_WIDTH-1:0] sew,
	input      [     OPSEL_WIDTH-1:0] opSel,
	output reg [ RESP_DATA_WIDTH-1:0] out_vec
);

	wire [ RESP_DATA_WIDTH-1:0] op_out;
	wire [RESP_DATA_WIDTH+16:0] result;
	wire [ RESP_DATA_WIDTH-1:0]	minMax_result;

	vAdd_unit_block	vAdd_unit0 (
		.clk   	(clk 									),
		.rst   	(rst 									),
		.vec0  	(vec0[REQ_DATA_WIDTH-1:0]				),
		.vec1  	(vec0[REQ_DATA_WIDTH*2-1:REQ_DATA_WIDTH]),
		.carry	(1'b0 									),
		.sew   	(sew									),
		.opSel 	('h0 									),
		.result	(result									)
	);

	generate
		if(MIN_MAX_ENABLE == 1) begin
			vMinMaxSelector vMinMaxSelector0 (
				.vec0			(vec0[REQ_DATA_WIDTH-1:0]				),
				.vec1			(vec0[REQ_DATA_WIDTH*2-1:REQ_DATA_WIDTH]),
				.sub_result 	(result 								),
				.sew 			(sew 									),
				.minMax_sel 	(opSel[0] 								),
				.minMax_result 	(minMax_result 							),
				.equal			(										),
				.lt 			(										)
			);
		end
	endgenerate

	generate
		if (REQ_DATA_WIDTH >= 64) begin
			assign op_out	= {result[78:71],result[68:61],result[58:51],result[48:41],result[38:31],result[28:21],result[18:11],result[8:1]};
		end else if (REQ_DATA_WIDTH >= 32) begin
			assign op_out	= {32'h0,result[38:31],result[28:21],result[18:11],result[8:1]};
		end else if (REQ_DATA_WIDTH >= 16) begin
			assign op_out	= {48'h0,result[18:11],result[8:1]};
		end else begin
			assign op_out	= {56'h0,result[8:1]};
		end
	endgenerate

	always @(posedge clk) begin
		if (rst) begin
			out_vec <= 'h0;
		end else begin
			out_vec <= en ? (opSel[1] ? minMax_result[REQ_DATA_WIDTH-1:0] : op_out[REQ_DATA_WIDTH-1:0]) : vec0[REQ_DATA_WIDTH-1:0];
		end
	end


endmodule