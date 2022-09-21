module vAndOrXor #(
	parameter REQ_DATA_WIDTH    = 64,
	parameter RESP_DATA_WIDTH   = 64,
	parameter REQ_ADDR_WIDTH 	= 32,
	parameter OPSEL_WIDTH       = 2,
	parameter VEC_MOVE_ENABLE 	= 1,
	parameter WHOLE_REG_ENABLE  = 1
) (
	input                              	clk     ,
	input                              	rst     ,
	input		[ REQ_ADDR_WIDTH-1:0] 	in_addr	,
	input      	[ REQ_DATA_WIDTH-1:0] 	in_vec0 ,
	input      	[ REQ_DATA_WIDTH-1:0] 	in_vec1 ,
	input                              	in_valid,
	input      	[	 OPSEL_WIDTH-1:0] 	in_opSel, //01=and,10=or,11=xor
	input 								in_sca	,
	input 								in_w_reg,
	output reg 	[RESP_DATA_WIDTH-1:0] 	out_vec ,
	output reg							out_valid,
	output reg 	[ REQ_ADDR_WIDTH-1:0] 	out_addr,
	output reg 						 	out_w_reg,
	output reg 						 	out_sca
	);

	reg [ REQ_DATA_WIDTH-1:0] s0_vec0, s0_vec1;
	reg [    OPSEL_WIDTH-1:0] s0_opSel;
	reg [RESP_DATA_WIDTH-1:0] s1_out_vec, s2_out_vec, s3_out_vec, s4_out_vec;
	reg                       s0_valid, s1_valid, s2_valid, s3_valid, s4_valid;
	reg [ REQ_ADDR_WIDTH-1:0] s0_out_addr, s1_out_addr, s2_out_addr, s3_out_addr, s4_out_addr;

	// for vMove
	reg 						s0_w_reg, s1_w_reg, s2_w_reg, s3_w_reg, s4_w_reg;
  	reg 						s0_sca, s1_sca, s2_sca, s3_sca, s4_sca;

  	generate
  		if (VEC_MOVE_ENABLE) begin
	  		if (WHOLE_REG_ENABLE) begin
	  			always @(posedge clk) begin
	  				if(rst) begin
	  					s0_w_reg 	<= 0;
						s1_w_reg 	<= 0;
						s2_w_reg 	<= 0;
						s3_w_reg 	<= 0;
						s4_w_reg 	<= 0;
		            	out_w_reg 	<= 0;
	  				end else begin
	  					s0_w_reg 	<= in_w_reg & in_valid;
						s1_w_reg 	<= s0_w_reg;
						s2_w_reg 	<= s1_w_reg;
						s3_w_reg 	<= s2_w_reg;
						s4_w_reg 	<= s3_w_reg;
						out_w_reg  	<= s4_w_reg;
	  				end
	  			end
	  		end else begin
	  			always @(*) begin
	  				s0_w_reg 	= 0;
					s1_w_reg 	= 0;
					s2_w_reg 	= 0;
					s3_w_reg 	= 0;
					s4_w_reg 	= 0;
            		out_w_reg 	= 0;
	  			end
	  		end
	  		always @(posedge clk ) begin : proc_
	  			if(rst) begin
	  				s0_sca	<= 0;
					s1_sca	<= 0;
					s2_sca	<= 0;
					s3_sca	<= 0;
					s4_sca	<= 0;
            		out_sca	<= 0;
	  			end else begin
	  				s0_sca	<= in_sca & in_valid;
					s1_sca	<= s0_sca;
					s2_sca	<= s1_sca;
					s3_sca	<= s2_sca;
					s4_sca	<= s3_sca;
					out_sca	<= s4_sca;
	  			end
	  		end
	  	end
	  	else begin
	  		always @(*) begin
            	out_w_reg 	= 0;
            	out_sca		= 0;
	  		end
	  	end
  	endgenerate

	always @(posedge clk) begin
		if(rst) begin
			s0_vec0    	<= 'b0;
			s0_vec1    	<= 'b0;
			s0_opSel   	<= 'b0;
			s1_out_vec 	<= 'b0;
			s2_out_vec 	<= 'b0;
			s3_out_vec 	<= 'b0;
			s4_out_vec 	<= 'b0;
			out_vec   	<= 'b0;

			s0_valid 	<= 'b0;
			s1_valid 	<= 'b0;
			s2_valid 	<= 'b0;
			s3_valid 	<= 'b0;
			s4_valid 	<= 'b0;
			out_valid 	<= 'b0;

			s0_out_addr <= 'b0;
			s1_out_addr <= 'b0;
			s2_out_addr <= 'b0;
			s3_out_addr <= 'b0;
			s4_out_addr <= 'b0;
			out_addr 	<= 'b0;
		end else begin
			s0_vec0    	<= in_valid ? in_vec0 : 'h0;
			s0_vec1    	<= in_valid ? in_vec1 : 'h0;
			s0_opSel   	<= in_valid ? in_opSel : 'h0;

			case(s0_opSel)
				2'b01 : s1_out_vec <= s0_vec0 & s0_vec1;
				2'b10 : s1_out_vec <= s0_vec0 | s0_vec1;
				2'b11 : s1_out_vec <= s0_vec0 ^ s0_vec1;
				default : s1_out_vec <= 'b0;
			endcase
			
			s2_out_vec 	<= s1_out_vec;
			s3_out_vec 	<= s2_out_vec;
			s4_out_vec 	<= s3_out_vec;
			out_vec 	<= s4_out_vec;

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