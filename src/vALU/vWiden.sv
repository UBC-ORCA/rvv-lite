module vWiden 
  #(
    parameter REQ_DATA_WIDTH    = 64,
    parameter RESP_DATA_WIDTH   = 64,
    parameter OPSEL_WIDTH       = 2,
    parameter SEW_WIDTH         = 2,
    parameter REQ_BYTE_EN_WIDTH = REQ_DATA_WIDTH/8
  ) 
  (
   input  logic [REQ_DATA_WIDTH-1:0] in_vec,
   input  logic [SEW_WIDTH-1:0] in_sew,
   input  logic in_turn,
   input  logic [REQ_BYTE_EN_WIDTH-1:0] in_be,
   input  logic in_signed,
   output logic [REQ_BYTE_EN_WIDTH-1:0] out_be,
   output logic [RESP_DATA_WIDTH-1:0] out_vec,
   output logic [SEW_WIDTH-1:0] out_sew
  );

  always @(*) begin
    case ({in_turn,in_sew})
        3'b110: out_vec = {{32{in_signed&in_vec[63]}},in_vec[63:32]};
        3'b101: out_vec = {{16{in_signed&in_vec[63]}},in_vec[63:48],{16{in_signed&in_vec[47]}},in_vec[47:32]};
        3'b100: out_vec = {{8{in_signed&in_vec[63]}},in_vec[63:56],{8{in_signed&in_vec[55]}},in_vec[55:48],
                            {8{in_signed&in_vec[47]}},in_vec[47:40],{8{in_signed&in_vec[39]}},in_vec[39:32]};
        3'b010: out_vec = {{32{in_signed&in_vec[31]}},in_vec[31:0]};
        3'b001: out_vec = {{16{in_signed&in_vec[31]}},in_vec[31:16],{16{in_signed&in_vec[15]}},in_vec[15:0]};
        3'b000: out_vec = {{8{in_signed&in_vec[31]}},in_vec[31:24],{8{in_signed&in_vec[23]}},in_vec[23:16],
                            {8{in_signed&in_vec[15]}},in_vec[15:8],{8{in_signed&in_vec[7]}},in_vec[7:0]};
        default:  out_vec = 'h0;
    endcase
  end 

  assign out_be   = in_turn ? {{2{in_be[7]}},{2{in_be[6]}},{2{in_be[5]}},{2{in_be[4]}}} : {{2{in_be[3]}},{2{in_be[2]}},{2{in_be[1]}},{2{in_be[0]}}};
  assign out_sew  = in_sew + 2'b01;
    
endmodule
