module vADD # (
	parameter VECTOR_WIDTH=64,
	parameter DATA_WIDTH=64,
	parameter VECTOR_BYTE=8,
	parameter ADDR_WITH=32

)(
	input clk,
	input rst,
	input [VECTOR_WIDTH-1:0] in_vec1,
	input [VECTOR_WIDTH-1:0] in_vec2,
	input [VECTOR_BYTE-1:0] byte_en, 
	input in_valid,
	input [ADDR_WITH-1:0] in_addr,
	output reg [VECTOR_WIDTH-1:0] out_vec,
	output reg out_valid,
	output reg [ADDR_WITH-1:0] out_addr
);


	always @(posedge clk) begin
		if(rst) begin
			out_valid <= 'b0;
			out_vec <= 'b0;
			out_addr <= 'b0;
		end

		else if(in_valid & byte_en[0])begin
			out_vec <= in_vec1 + in_vec2;
			out_valid <= in_valid;
			out_addr <= in_addr;
		end
	end


endmodule
