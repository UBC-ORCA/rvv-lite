module vAdd_unit_block #(
	parameter REQ_DATA_WIDTH    = 64,
	parameter RESP_DATA_WIDTH   = 64,
	parameter SEW_WIDTH         = 2 ,
	parameter OPSEL_WIDTH       = 5
) (
	input                              	clk,
	input                              	rst,
	input      [  REQ_DATA_WIDTH-1:0] 	vec0,
	input      [  REQ_DATA_WIDTH-1:0] 	vec1,
	input 	   [  REQ_DATA_WIDTH-1:0]	carry,
	input      [	   SEW_WIDTH-1:0]	sew,
	input      [	 OPSEL_WIDTH-1:0]	opSel,
	output     [RESP_DATA_WIDTH+16:0]	result
);

	genvar i;

	wire [  REQ_DATA_WIDTH-1:0]	w_vec0, w_vec1;
	wire [ REQ_DATA_WIDTH+15:0]	w_op0, w_op1;
	wire [ REQ_DATA_WIDTH+16:0]	w_result;
	wire 						is_sub;
	wire 						v0_ext0, v0_ext1, v0_ext2, v0_ext4;
	wire 						v1_ext0, v1_ext1, v1_ext2, v1_ext4;
	wire [REQ_DATA_WIDTH/8-1:0] v0_sgn, v1_sgn;

	assign is_sub 	= opSel[1];
	assign v0_ext0	= is_sub;
	assign v1_ext0	= is_sub;
	assign v0_ext1	= (sew[1] | sew[0]) ? 1'b1 : is_sub;
	assign v1_ext1	= (sew[1] | sew[0]) ? 1'b0 : is_sub;
	assign v0_ext2	= (sew[1]) ? 1'b1 : is_sub;
	assign v1_ext2	= (sew[1]) ? 1'b0 : is_sub;
	assign v0_ext4	= (sew[1] & sew[0]) ? 1'b1 : is_sub;
	assign v1_ext4	= (sew[1] & sew[0]) ? 1'b0 : is_sub;

	assign w_vec0	= (opSel[1] & opSel[0]) 		? ~(vec0) : vec0;
	assign w_vec1	= (opSel[1] & (~(opSel[0])))	? ~(vec1) : vec1;

	generate
		for(i=0;i<8;i=i+1) begin
			assign v0_sgn[i]	= ~opSel[4] | (opSel[2] & vec0[i*8+7]);
			assign v1_sgn[i]	= opSel[4] & ~(opSel[2] & vec1[i*8+7]);
		end
	endgenerate

	assign w_op0 	= {
		v0_sgn[7],w_vec0[63:56],v0_ext1,
		v0_sgn[6],w_vec0[55:48],v0_ext2,
		v0_sgn[5],w_vec0[47:40],v0_ext1,
		v0_sgn[4],w_vec0[39:32],v0_ext4,
		v0_sgn[3],w_vec0[31:24],v0_ext1,
		v0_sgn[2],w_vec0[23:16],v0_ext2,
		v0_sgn[1],w_vec0[15:8] ,v0_ext1,
		v0_sgn[0],w_vec0[7:0]  ,is_sub};

	assign w_op1 	= {
		v1_sgn[7],w_vec1[63:56],v1_ext1,
		v1_sgn[6],w_vec1[55:48],v1_ext2,
		v1_sgn[5],w_vec1[47:40],v1_ext1,
		v1_sgn[4],w_vec1[39:32],v1_ext4,
		v1_sgn[3],w_vec1[31:24],v1_ext1,
		v1_sgn[2],w_vec1[23:16],v1_ext2,
		v1_sgn[1],w_vec1[15:8] ,v1_ext1,
		v1_sgn[0],w_vec1[7:0]  ,is_sub};

	assign result 	= w_op0 + w_op1 + carry;

endmodule