module round_fxp
#(
	parameter DATA_WIDTH = 64
)(
	input  logic			clk,
	input  logic			rst,
	input  logic [  DATA_WIDTH:0] result_in, // suspect that we are dealing with an output of DATA_WIDTH+1 bits
	input  logic [	   1:0] vxrm,
	input  logic [ 	   1:0] sew,
	output logic [DATA_WIDTH-1:0] result_out
);
	
always @(posedge clk) begin
	if (rst) begin
		result_out <= 'h0;
	end else begin
		// 64 bit -- FIXME 32/16/8
		case (vxrm)
			2'b00: result_out <= (result_in[DATA_WIDTH:1] + result_in[0]);
			2'b01: result_out <= (result_in[DATA_WIDTH:1] + (result_in[1] & result_in[0]));
			2'b10: result_out <= (result_in[DATA_WIDTH:1]);
			2'b11: result_out <= (result_in[DATA_WIDTH:1] + (~result_in[1] & result_in[0]));
		endcase
	end
end

endmodule
