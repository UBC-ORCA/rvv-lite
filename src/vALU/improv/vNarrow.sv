module vNarrow 
  #(
    parameter REQ_DATA_WIDTH    = 64,
    parameter NARROW_DATA_WIDTH = REQ_DATA_WIDTH>>1,
    parameter RESP_DATA_WIDTH   = 64,
    parameter REQ_ADDR_WIDTH    = 32,
    parameter OPSEL_WIDTH       = 2,
    parameter SEW_WIDTH         = 2,
    parameter REQ_BYTE_EN_WIDTH = 8,
    parameter ENABLE_64_BIT     = 1
  ) 
  (
    input  logic clk,
    input  logic rst,
    input  logic [REQ_DATA_WIDTH-1:0] in_vec,
    input  logic in_valid,
    input  logic [SEW_WIDTH-1:0] in_sew,
    input  logic [REQ_BYTE_EN_WIDTH-1:0] in_be,
    output logic [REQ_BYTE_EN_WIDTH-1:0] out_be,
    output logic [RESP_DATA_WIDTH-1:0] out_vec,
    output logic out_valid,
    output logic [SEW_WIDTH-1:0] out_sew
  );

  localparam NUM_SEWS = 1 << SEW_WIDTH;
  logic [RESP_DATA_WIDTH-1:0] o_vecs[2][NUM_SEWS];
  logic [REQ_BYTE_EN_WIDTH-1:0] o_bes[2];
  logic turn;

  always @(posedge clk) begin
    // default
    turn <= 1'b0;
    if (in_valid)
      turn <= ~turn;

    if (rst)
      turn <= 1'b0;
  end

  genvar i, j, k;

  for (i = 0; i < 2; i++) begin
    assign o_vecs[i][0] = (REQ_DATA_WIDTH)'(0);
  end

  for (i = 0; i < 2; i++) begin
    for (j = 1; j < NUM_SEWS-1; j++) begin
      localparam W = 8*(1 << j);
      for (k = 0; k < REQ_DATA_WIDTH/W; k++) begin
        assign o_vecs[i][j][i*REQ_DATA_WIDTH/2 + k*W/2 +: W/2] = in_vec[k*W +: W/2];
      end
      assign o_vecs[i][j][(1-i)*REQ_DATA_WIDTH/2 +: REQ_DATA_WIDTH/2] = (REQ_DATA_WIDTH/2)'(0);
    end
  end

  for (i = 0; i < 2; i++) begin
    if (ENABLE_64_BIT) begin
      localparam W = 8*(1 << (NUM_SEWS-1));
      for (k = 0; k < REQ_DATA_WIDTH/W; k++) begin
        assign o_vecs[i][NUM_SEWS-1][i*REQ_DATA_WIDTH/2 + k*W/2 +: W/2] = in_vec[k*W +: W/2];
      end
      assign o_vecs[i][NUM_SEWS-1][(1-i)*REQ_DATA_WIDTH/2 +: REQ_DATA_WIDTH/2] = (REQ_DATA_WIDTH/2)'(0);
    end else begin
      assign o_vecs[i][NUM_SEWS-1] = (REQ_DATA_WIDTH)'(0);
    end
  end
  
  for (i = 0; i < 2; i++) begin
    localparam W = 1;
    for (k = 0; k < REQ_BYTE_EN_WIDTH/W; k++) begin
      //assign o_bes[i][i*REQ_BYTE_EN_WIDTH/2 + k*W/2 +: W/2] = in_be[k*W +: W/2];
      if (k % 2 == 0)
        assign o_bes[i][i*REQ_BYTE_EN_WIDTH/2 + k*W/2] = in_be[k*W];
    end
    assign o_bes[i][(1-i)*REQ_BYTE_EN_WIDTH/2 +: REQ_BYTE_EN_WIDTH/2] = (REQ_BYTE_EN_WIDTH/2)'(0);
  end

  assign out_vec    = o_vecs[turn][in_sew];
  assign out_be     = o_bes[turn];
  assign out_valid  = in_valid;
  assign out_sew    = in_sew - 2'b01;

endmodule
