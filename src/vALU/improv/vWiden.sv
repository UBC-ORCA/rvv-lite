module vWiden 
  #(
    parameter REQ_DATA_WIDTH    = 64,
    parameter RESP_DATA_WIDTH   = 64,
    parameter OPSEL_WIDTH       = 2,
    parameter SEW_WIDTH         = 2,
    parameter REQ_BYTE_EN_WIDTH = REQ_DATA_WIDTH/8
  ) 
  (
   input  logic [REQ_DATA_WIDTH-1:0] in_vec0,
   input  logic [REQ_DATA_WIDTH-1:0] in_vec1,
   input  logic [SEW_WIDTH-1:0] in_sew,
   input  logic in_turn,
   input  logic [REQ_BYTE_EN_WIDTH-1:0] in_be,
   input  logic in_signed0,
   input  logic in_signed1,
   output logic [REQ_BYTE_EN_WIDTH-1:0] out_be,
   output logic [RESP_DATA_WIDTH-1:0] out_vec0,
   output logic [RESP_DATA_WIDTH-1:0] out_vec1,
   output logic [SEW_WIDTH-1:0] out_sew
  );

  logic [REQ_DATA_WIDTH-1:0] i_vecs[2];
  logic [REQ_DATA_WIDTH-1:0] o_vecs[2][2][1 << SEW_WIDTH];
  logic [REQ_BYTE_EN_WIDTH-1:0] o_bes[2];
  logic i_signs[2];

  assign i_vecs[0] = in_vec0;
  assign i_vecs[1] = in_vec1;
  assign i_signs[0] = in_signed0;
  assign i_signs[1] = in_signed1;

  genvar n, i, j, k;

  for (n = 0; n < 2; n++) begin
    for (i = 0; i < 2; i++) begin
      for (j = 0; j < 3; j++) begin
        localparam W = 8*(1 << j);
        for (k = 0; k < (REQ_DATA_WIDTH/2)/W; k++) begin
            assign o_vecs[n][i][j][k*2*W +: 2*W] = i_signs[n] ? (2*W)'(signed'(i_vecs[n][i*REQ_DATA_WIDTH/2 + k*W +: W])) : (2*W)'(i_vecs[n][i*REQ_DATA_WIDTH/2 + k*W +: W]);
        end
      end
    end
  end

  for (n = 0; n < 2; n++) begin
    for (i = 0; i < 2; i++) begin
      assign o_vecs[n][i][3] = 'b0;
    end
  end

  for (i = 0; i < 2; i++) begin
    for (k = 0; k < (REQ_DATA_WIDTH/2)/8; k++) begin
      assign o_bes[i][k*2*1 +: 2*1] = {2{in_be[i*(REQ_DATA_WIDTH/2)/8 + k*1 +: 1]}};
    end
  end

  assign out_vec0 = o_vecs[0][in_turn][in_sew];
  assign out_vec1 = o_vecs[1][in_turn][in_sew];
  assign out_be   = o_bes[in_turn];
  assign out_sew  = in_sew + 2'b01;
    
endmodule
