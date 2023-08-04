module vRedAndOrXor_unit_block 
  #(
    parameter REQ_DATA_WIDTH  = 32,
    parameter RESP_DATA_WIDTH = 32,
    parameter OPSEL_WIDTH     = 2,
    parameter ENABLE_64_BIT   = 0
  )
  (
    input  logic clk,
    input  logic rst,
    input  logic in_en,
    input  logic [2*REQ_DATA_WIDTH-1:0] in_vec0,
    input  logic [OPSEL_WIDTH-1:0] in_opSel,
    output logic [RESP_DATA_WIDTH-1:0] out_vec 
  );

  logic [RESP_DATA_WIDTH-1:0] w_vec;

  always_comb begin
    if (ENABLE_64_BIT | REQ_DATA_WIDTH < 64) begin
      unique case (in_opSel[1:0])
        2'b00: w_vec = 'b0;
        2'b01: w_vec = (in_vec0[0 +: REQ_DATA_WIDTH] & in_vec0[REQ_DATA_WIDTH +: REQ_DATA_WIDTH]);
        2'b10: w_vec = (in_vec0[0 +: REQ_DATA_WIDTH] | in_vec0[REQ_DATA_WIDTH +: REQ_DATA_WIDTH]);
        2'b11: w_vec = (in_vec0[0 +: REQ_DATA_WIDTH] ^ in_vec0[REQ_DATA_WIDTH +: REQ_DATA_WIDTH]);
      endcase
    end else begin
      unique case (in_opSel[1:0])
        2'b00: w_vec = {32'b0, 'b0};
        2'b01: w_vec = {32'b0, (in_vec0[31:0] & in_vec0[91:64])};
        2'b10: w_vec = {32'b0, (in_vec0[31:0] | in_vec0[91:64])};
        2'b11: w_vec = {32'b0, (in_vec0[31:0] ^ in_vec0[91:64])};
      endcase
    end
  end

  always_ff @(posedge clk) begin
    if (in_en) begin
      if (ENABLE_64_BIT | REQ_DATA_WIDTH < 64) begin
        out_vec <= w_vec;
      end else begin
        out_vec <= w_vec[REQ_DATA_WIDTH/2-1:0];
      end
    end else begin
      if (ENABLE_64_BIT | REQ_DATA_WIDTH < 64) begin
        out_vec <= in_vec0;
      end else begin
        out_vec <= in_vec0[REQ_DATA_WIDTH/2-1:0];
      end
    end

    if (rst) begin
      out_vec <= 0;
    end 
  end

endmodule
