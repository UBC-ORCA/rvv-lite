// `include "vMinMaxSelector.v"
// `include "vAdd_unit_block.v"

module vRedSum_min_max_unit_block #(
	parameter REQ_DATA_WIDTH  	= 32,
	parameter RESP_DATA_WIDTH 	= 64,
	parameter OPSEL_WIDTH     	= 2 ,
	parameter SEW_WIDTH       	= 2 ,
	parameter MIN_MAX_ENABLE  	= 1 ,
	parameter ENABLE_64_BIT 	= 0
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

	if (ENABLE_64_BIT | REQ_DATA_WIDTH < 64) begin
		vAdd_unit_block #(.ENABLE_64_BIT(ENABLE_64_BIT)
		)	vAdd_unit0 (
			.clk   	(clk 									),
			.rst   	(rst 									),
			.vec0  	(vec0[REQ_DATA_WIDTH-1:0]				),
			.vec1  	(vec0[REQ_DATA_WIDTH*2-1:REQ_DATA_WIDTH]),
			.carry	('h0 									),
			.sew   	(sew									),
			.opSel 	('h0 									),
			.result	(result									)
		);
	end else begin
		vAdd_unit_block #(.ENABLE_64_BIT(ENABLE_64_BIT)
		)	vAdd_unit0 (
			.clk   	(clk 					),
			.rst   	(rst 					),
			.vec0  	({32'b0,vec0[31:0]}		),
			.vec1  	({32'b0,vec0[91:64]}	),
			.carry	('h0 					),
			.sew   	(sew					),
			.opSel 	('h0 					),
			.result	(result					)
		);
	end

	generate
		if(MIN_MAX_ENABLE) begin
			if (ENABLE_64_BIT | REQ_DATA_WIDTH < 64) begin
				vMinMaxSelector #(.ENABLE_64_BIT(ENABLE_64_BIT)
				) vMinMaxSelector0 (
					.vec0			(vec0[REQ_DATA_WIDTH-1:0]				),
					.vec1			(vec0[REQ_DATA_WIDTH*2-1:REQ_DATA_WIDTH]),
					.sub_result 	(result 								),
					.sew 			(sew 									),
					.minMax_sel 	(opSel[0] 								),
					.minMax_result 	(minMax_result 							),
					.equal			(										),
					.lt 			(										)
				);
			end else begin
				vMinMaxSelector #(.ENABLE_64_BIT(ENABLE_64_BIT)
				) vMinMaxSelector0 (
					.vec0			({32'b0,vec0[31:0]}		),
					.vec1			({32'b0,vec0[91:64]}	),
					.sub_result 	(result 				),
					.sew 			(sew 					),
					.minMax_sel 	(opSel[0] 				),
					.minMax_result 	(minMax_result 			),
					.equal			(						),
					.lt 			(						)
				);
			end
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

		always @(posedge clk) begin
			if (rst) begin
				out_vec <= 'h0;
			end else begin
				if (ENABLE_64_BIT | REQ_DATA_WIDTH < 64) begin
					out_vec <= en ? (opSel[1] ? minMax_result[REQ_DATA_WIDTH-1:0] : op_out[REQ_DATA_WIDTH-1:0]) : vec0[REQ_DATA_WIDTH-1:0];
				end else begin
					out_vec <= en ? (opSel[1] ? minMax_result[(REQ_DATA_WIDTH/2) - 1:0] : op_out[(REQ_DATA_WIDTH/2):0]) : vec0[(REQ_DATA_WIDTH/2):0];
				end
			end
		end
	endgenerate


endmodule