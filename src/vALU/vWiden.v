module vWiden #(
	parameter REQ_DATA_WIDTH    = 64,
	parameter RESP_DATA_WIDTH   = 64,
	parameter OPSEL_WIDTH       = 2,
	parameter SEW_WIDTH         = 2,
	parameter REQ_BYTE_EN_WIDTH = REQ_DATA_WIDTH/8
) (
	input      [   REQ_DATA_WIDTH-1:0]	in_vec0  ,
	input      [   REQ_DATA_WIDTH-1:0] 	in_vec1  ,
	input      [        SEW_WIDTH-1:0] 	in_sew,
	input							   	in_turn,
	input      [REQ_BYTE_EN_WIDTH-1:0]	in_be,
	input                              	in_signed0,
    input                               in_signed1,
	output     [REQ_BYTE_EN_WIDTH-1:0]  out_be,
	output reg [  RESP_DATA_WIDTH-1:0] 	out_vec0,
	output reg [  RESP_DATA_WIDTH-1:0] 	out_vec1,
	output     [		SEW_WIDTH-1:0]  out_sew
);

	
    always @(*) begin
        case ({in_turn,in_sew})
            3'b110: out_vec0  = {{32{in_signed0&in_vec0[63]}},in_vec0[63:32]};
            3'b101: out_vec0  = {{16{in_signed0&in_vec0[63]}},in_vec0[63:48],{16{in_signed0&in_vec0[47]}},in_vec0[47:32]};
            3'b100: out_vec0  = {{8{in_signed0&in_vec0[63]}},in_vec0[63:56],{8{in_signed0&in_vec0[55]}},in_vec0[55:48],
                                {8{in_signed0&in_vec0[47]}},in_vec0[47:40],{8{in_signed0&in_vec0[39]}},in_vec0[39:32]};
            3'b010: out_vec0  = {{32{in_signed0&in_vec0[31]}},in_vec0[31:0]};
            3'b001: out_vec0  = {{16{in_signed0&in_vec0[31]}},in_vec0[31:16],{16{in_signed0&in_vec0[15]}},in_vec0[15:0]};
            3'b000: out_vec0  = {{8{in_signed0&in_vec0[31]}},in_vec0[31:24],{8{in_signed0&in_vec0[23]}},in_vec0[23:16],
                                {8{in_signed0&in_vec0[15]}},in_vec0[15:8],{8{in_signed0&in_vec0[7]}},in_vec0[7:0]};
            default:  out_vec0 = 'h0;
        endcase
    end

    always @(*) begin
        case ({in_turn,in_sew})
            3'b110: out_vec1 = {{32{in_signed1&in_vec1[63]}},in_vec1[63:32]};
            3'b101: out_vec1 = {{16{in_signed1&in_vec1[63]}},in_vec1[63:48],{16{in_signed1&in_vec1[47]}},in_vec1[47:32]};
            3'b100: out_vec1 = {{8{in_signed1&in_vec1[63]}},in_vec1[63:56],{8{in_signed1&in_vec1[55]}},in_vec1[55:48],
                                {8{in_signed1&in_vec1[47]}},in_vec1[47:40],{8{in_signed1&in_vec1[39]}},in_vec1[39:32]};
            3'b010: out_vec1 = {{32{in_signed1&in_vec1[31]}},in_vec1[31:0]};
            3'b001: out_vec1 = {{16{in_signed1&in_vec1[31]}},in_vec1[31:16],{16{in_signed1&in_vec1[15]}},in_vec1[15:0]};
            3'b000: out_vec1 = {{8{in_signed1&in_vec1[31]}},in_vec1[31:24],{8{in_signed1&in_vec1[23]}},in_vec1[23:16],
                                {8{in_signed1&in_vec1[15]}},in_vec1[15:8],{8{in_signed1&in_vec1[7]}},in_vec1[7:0]};
            default:  out_vec1 = 'h0;
        endcase
    end 

    assign out_be   = in_turn ? {{2{in_be[7]}},{2{in_be[6]}},{2{in_be[5]}},{2{in_be[4]}}} : {{2{in_be[3]}},{2{in_be[2]}},{2{in_be[1]}},{2{in_be[0]}}};

    assign out_sew  = in_sew + 2'b01;

endmodule