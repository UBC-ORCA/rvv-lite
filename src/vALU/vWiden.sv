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

  localparam NUM_SEWS = 1 << SEW_WIDTH;
  logic [RESP_DATA_WIDTH-1:0] o_vecs[2][NUM_SEWS];
  logic [REQ_BYTE_EN_WIDTH-1:0] o_bes[2];

  genvar i, j, k;

  for (i = 0; i < 2; i++) begin
    for (j = 0; j < NUM_SEWS-1; j++) begin
      localparam W = 8*(1 << j);
      for (k = 0; k < (REQ_DATA_WIDTH/2)/W; k++) begin
          assign o_vecs[i][j][k*2*W +: 2*W] = in_signed ? (2*W)'(signed'(in_vec[i*REQ_DATA_WIDTH/2 + k*W +: W])):
                                                          (2*W)'(in_vec[i*REQ_DATA_WIDTH/2 + k*W +: W]);
      end
    end
  end

  for (i = 0; i < 2; i++) begin
    assign o_vecs[i][NUM_SEWS-1] = (REQ_DATA_WIDTH)'(0);
  end

  for (i = 0; i < 2; i++) begin
    localparam W = 1;
    for (k = 0; k < (REQ_BYTE_EN_WIDTH/2)/W; k++) begin
      assign o_bes[i][k*2*W +: 2*W] = {2{in_be[i*(REQ_BYTE_EN_WIDTH/2)/W + k*W +: W]}};
    end
  end

  assign out_vec  = o_vecs[in_turn][in_sew];
  assign out_be   = o_bes[in_turn];
  assign out_sew  = in_sew + 2'b01;
    
endmodule
