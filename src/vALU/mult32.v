module mult32 #(
	parameter INPUT_WIDTH	= 18,
	parameter ADD_SHIFT   	= 0
) (
	input                                 	clk             ,
	input                                  	rst             ,
	input      signed [   INPUT_WIDTH-1:0] 	in_a0           ,
	input      signed [   INPUT_WIDTH-1:0] 	in_a1           ,
	input      signed [   INPUT_WIDTH-1:0] 	in_b0           ,
	input      signed [   INPUT_WIDTH-1:0] 	in_b1           ,
	output reg signed [ INPUT_WIDTH*2-2:0] 	out_mult16_p0,
	output reg signed [ INPUT_WIDTH*2-2:0] 	out_mult16_p1,
	output reg signed [INPUT_WIDTH*2+30:0] 	out_mult32
);

	wire signed [32:0]	w_prod16_a0_b0, w_prod16_a0_b1, w_prod16_a1_b0, w_prod16_a1_b1;
	wire signed [65:0]	w_prod_32;

	reg signed [ 32:0]	prod16_a0_b0, prod16_a0_b1, prod16_a1_b0, prod16_a1_b1;
	
	reg signed [64:0] 	add1;
	reg signed [64:0] 	add2;
	wire signed [64:0] 	w_add1;
	wire signed [64:0] 	w_add2;

	assign w_prod16_a0_b0 	= in_a0 * in_b0;
	assign w_prod16_a1_b1   = in_a1 * in_b1;
	assign w_prod16_a0_b1   = in_a0 * in_b1;
	assign w_prod16_a1_b0   = in_a1 * in_b0;

	assign w_add1 			= {{16{w_prod16_a0_b1[32]}},w_prod16_a0_b1,16'b0} + {{16{w_prod16_a1_b0[32]}},w_prod16_a1_b0,16'b0};
	assign w_add2 			= {w_prod16_a0_b0,32'b0} + {{32{w_prod16_a1_b1[32]}},w_prod16_a1_b1};

	assign w_prod_32 		= add1+add2;

	always @(posedge clk) begin
		if(rst) begin
			prod16_a0_b0 	<= 'b0;
			prod16_a0_b1 	<= 'b0;
			prod16_a1_b0 	<= 'b0;
			prod16_a1_b1 	<= 'b0;
			out_mult16_p0	<= 'b0;
			out_mult16_p1	<= 'b0;
			out_mult32 		<= 'b0;
			add1 			<= 'b0;
			add2 			<= 'b0;
		end

		else begin
			prod16_a0_b0 	<= w_prod16_a0_b0;
			prod16_a0_b1 	<= w_prod16_a0_b1;
			prod16_a1_b0 	<= w_prod16_a1_b0;
			prod16_a1_b1 	<= w_prod16_a1_b1;
			out_mult16_p0 	<= prod16_a0_b0;
			out_mult16_p1 	<= prod16_a1_b1;
			out_mult32 		<= w_prod_32;
			add1 			<= w_add1;
			add2 			<= w_add2;
		end
	end

endmodule