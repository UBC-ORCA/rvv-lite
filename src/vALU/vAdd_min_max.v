// `include "vMinMaxSelector.v"
// `include "vAdd_unit_block.v"

module vAdd_min_max #(
	parameter REQ_DATA_WIDTH  = 64,
	parameter RESP_DATA_WIDTH = 64,
	parameter REQ_ADDR_WIDTH  = 32,
	parameter SEW_WIDTH       = 2 ,
	parameter OPSEL_WIDTH     = 9 ,
	parameter MIN_MAX_ENABLE  = 1
) (
	input                            clk      ,
	input                            rst      ,
	input      [ REQ_DATA_WIDTH-1:0] in_vec0  ,
	input      [ REQ_DATA_WIDTH-1:0] in_vec1  ,
	input                            in_valid ,
	input      [      SEW_WIDTH-1:0] in_sew   ,
	input      [    OPSEL_WIDTH-1:0] in_opSel ,
	input                            in_carry ,
	input	   [ REQ_ADDR_WIDTH-1:0] in_addr  ,
	output reg [RESP_DATA_WIDTH-1:0] out_vec  ,
	output reg                       out_valid,
	output reg [ REQ_ADDR_WIDTH-1:0] out_addr
);

	genvar i;

	reg [ REQ_DATA_WIDTH-1:0] s0_vec0, s1_vec0;
	reg [ REQ_DATA_WIDTH-1:0] s0_vec1, s1_vec1;
	reg [RESP_DATA_WIDTH-1:0] s2_out_vec, s3_out_vec, s4_out_vec;
	reg [      SEW_WIDTH-1:0] s0_sew, s1_sew;
	reg [    OPSEL_WIDTH-1:0] s0_opSel, s1_opSel, s2_opSel;
	reg                       s0_valid, s1_valid, s2_valid, s3_valid, s4_valid;
	reg [                7:0] s2_gt, s2_lt, s2_equal;

	reg [ REQ_ADDR_WIDTH-1:0] s0_out_addr, s1_out_addr, s2_out_addr, s3_out_addr, s4_out_addr;

	wire [REQ_DATA_WIDTH+16:0] s1_result;

	wire [RESP_DATA_WIDTH-1:0] w_minMax_result  ;
	wire [RESP_DATA_WIDTH-1:0] w_s2_arith_result;
	wire [                7:0] w_gt, w_lt, w_equal;

	generate
		if(MIN_MAX_ENABLE == 1) begin
			vMinMaxSelector vMinMaxSelector0 (
				.clk(clk),
				.rst(rst),
				.vec0(s1_vec0),
				.vec1(s1_vec1),
				.sub_result(s1_result),
				.sew(s1_sew),
				.minMax_sel(s1_opSel[3]),
				.minMax_result(w_minMax_result),
				.equal(w_equal),
				.gt(w_gt),
				.lt(w_lt)
			);
		end
	endgenerate


	assign w_s2_arith_result = {s1_result[78:71],s1_result[68:61],s1_result[58:51],s1_result[48:41],s1_result[38:31],s1_result[28:21],s1_result[18:11],s1_result[8:1]};


	vAdd_unit_block vAdd_unit0 (
		.clk   (clk      ),
		.rst   (rst      ),
		.vec0  (s0_vec0  ),
		.vec1  (s0_vec1  ),
		.carry (1'b0	 ),
		.sew   (s0_sew   ),
		.opSel (s0_opSel ),
		.result(s1_result)
	);


	always @(posedge clk) begin
		if(rst) begin
			s0_vec0    	<= 'b0;
			s1_vec0    	<= 'b0;
			s0_vec1    	<= 'b0;
			s1_vec1    	<= 'b0;
			s2_out_vec 	<= 'b0;
			s3_out_vec 	<= 'b0;
			s4_out_vec 	<= 'b0;
			out_vec    	<= 'b0;

			s0_sew     	<= 'b0;
			s1_sew     	<= 'b0;

			s0_opSel   	<= 'b0;
			s1_opSel   	<= 'b0;
			s2_opSel   	<= 'b0;

			s0_valid   	<= 'b0;
			s1_valid   	<= 'b0;
			s2_valid   	<= 'b0;
			s3_valid   	<= 'b0;
			s4_valid   	<= 'b0;
			out_valid  	<= 'b0;

			s2_equal   	<= 'b0;
			s2_gt      	<= 'b0;
			s2_lt      	<= 'b0;

			s0_out_addr	<= 'b0;
			s1_out_addr	<= 'b0;
			s2_out_addr	<= 'b0;
			s3_out_addr	<= 'b0;
			s4_out_addr	<= 'b0;
			out_addr   	<= 'b0;
		end

		else begin
			s0_vec0  	<= {REQ_DATA_WIDTH{in_valid}} & in_vec0;
			s0_vec1  	<= {REQ_DATA_WIDTH{in_valid}} & in_vec1;
			s0_sew   	<= {SEW_WIDTH{in_valid}} & in_sew;
			s0_valid 	<= in_valid;
			s0_opSel 	<= {OPSEL_WIDTH{in_valid}} & in_opSel;
			s0_out_addr	<= {REQ_ADDR_WIDTH{in_valid}} & in_addr;

			s1_vec0  	<= s0_vec0;
			s1_vec1  	<= s0_vec1;
			s1_sew   	<= s0_sew;
			s1_opSel 	<= s0_opSel;
			s1_valid 	<= s0_valid;
			s1_out_addr	<= s0_out_addr;

          	// min-max is combinational, so this returns the value a cycle early lol
			s2_valid   	<= s0_valid;
          	s2_opSel   	<= s0_opSel;
			s2_out_addr	<= s0_out_addr;
			s2_out_vec 	<= s1_opSel[4] ? w_minMax_result : w_s2_arith_result;
			s2_equal   	<= w_equal;
			s2_gt      	<= w_gt;
			s2_lt      	<= w_lt;
			
			s3_valid   	<= s2_valid;
			s3_out_addr	<= s2_out_addr;
			case(s2_opSel[8:5])
				4'b1000 : s3_out_vec 	<= s2_equal;
				4'b1001 : s3_out_vec 	<= ~s2_equal;
				4'b1101 : s3_out_vec 	<= (~s2_equal) & s2_gt;
				4'b1100 : s3_out_vec 	<= s2_equal & s2_gt;
				4'b1111 : s3_out_vec 	<= (~s2_equal) & s2_lt;
				4'b1110 : s3_out_vec 	<= s2_equal & s2_lt;
				default : s3_out_vec 	<= s2_out_vec;
			endcase

// 			s4_out_vec <= s3_out_vec;
// 			s4_valid   <= s3_valid;
//          s4_out_addr <= s3_out_addr;

			out_vec   	<= s3_out_vec;
			out_valid 	<= s3_valid;
			out_addr  	<= s3_out_addr;
		end
	end

endmodule