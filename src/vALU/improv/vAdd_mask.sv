module vAdd_mask
  #(
    parameter REQ_DATA_WIDTH  = 64,
    parameter RESP_DATA_WIDTH = 64,
    parameter DATA_WIDTH_BITS = $clog2(REQ_DATA_WIDTH)
  )
  (
    input  logic clk,
    input  logic rst,
    input  logic in_valid,
    input  logic [REQ_DATA_WIDTH-1:0] in_m0,
    input  logic [REQ_DATA_WIDTH-1:0] in_count,
    output logic [RESP_DATA_WIDTH-1:0] out_vec
  );

  logic [REQ_DATA_WIDTH-1:0] count;
  logic [DATA_WIDTH_BITS-1:0] popcount;
  logic [DATA_WIDTH_BITS-1:0] npopcount;

  // This may need to be updated
  always_comb begin
    npopcount = 0;
    for (int i = 0; i < REQ_DATA_WIDTH; i++) begin
      npopcount = npopcount + in_m0[i];
    end
  end

  always_ff @(posedge clk) begin
    if (in_valid) begin
      count <= in_count;
      popcount <= npopcount; 
    end else begin
      count <= 0;
      popcount <= 0;
    end

    if (rst) begin
      count <= 0;
      popcount <= 0;
    end
  end

  assign out_vec = count + popcount;

endmodule

