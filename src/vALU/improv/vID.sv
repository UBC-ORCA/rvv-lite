module vID 
  #(
    parameter REQ_BYTE_EN_WIDTH = 8,
    parameter REQ_DATA_WIDTH    = 64,
    parameter RESP_DATA_WIDTH   = 64,
    parameter REQ_ADDR_WIDTH    = 5,
    parameter SEW_WIDTH         = 2,
    parameter ENABLE_64_BIT     = 1
  ) 
  (
    input  logic clk,
    input  logic rst,
    input  logic in_valid,
    input  logic [SEW_WIDTH-1:0] in_sew,
    input  logic [11:0] in_start_idx,
    input  logic [REQ_ADDR_WIDTH-1:0] in_addr,
    output logic [REQ_ADDR_WIDTH-1:0] out_addr,
    output logic [RESP_DATA_WIDTH-1:0] out_vec,
    output logic out_valid
  );

    localparam NUM_STAGES = 6;
    localparam NUM_SEWS = 1 << SEW_WIDTH;
    logic [REQ_ADDR_WIDTH-1:0] addrs[NUM_STAGES];
    logic [REQ_DATA_WIDTH-1:0] vecs[NUM_STAGES];
    logic valids[NUM_STAGES];
    logic [REQ_DATA_WIDTH-1:0] i_vecs[NUM_SEWS];

    genvar j, k;

    for (j = 0; j < NUM_SEWS-1; j++) begin
      localparam W = 8*(1 << j);
      for (k = 0; k < REQ_DATA_WIDTH/W; k++) begin
        assign i_vecs[j][k*W +: W] = REQ_DATA_WIDTH'(in_start_idx + k);
      end
    end

    if (ENABLE_64_BIT) begin
      localparam W = 8*(1 << (NUM_SEWS-1));
      for (k = 0; k < REQ_DATA_WIDTH/W; k++) begin
        assign i_vecs[NUM_SEWS-1][k*W +: W] = REQ_DATA_WIDTH'(in_start_idx + k);
      end
    end else begin
      assign i_vecs[NUM_SEWS-1] = REQ_DATA_WIDTH'(0);
    end

    always_ff @(posedge clk) begin
      addrs[0]  <= in_valid ? in_addr : REQ_ADDR_WIDTH'(0);
      vecs[0]   <= in_valid ? i_vecs[in_sew] : REQ_DATA_WIDTH'(0);
      valids[0] <= in_valid;

      for (int s = 1; s < NUM_STAGES; s++) begin
        addrs[s]  <= addrs[s-1];
        vecs[s]   <= vecs[s-1];
        valids[s] <= valids[s-1];
      end

      if (rst) begin
        for (int s = 0; s < NUM_STAGES; s++) begin
          addrs[s]  <= REQ_ADDR_WIDTH'(0);
          vecs[s]   <= REQ_DATA_WIDTH'(0);
          valids[s] <= 1'b0;
        end
      end
    end

    assign out_addr  = addrs[NUM_STAGES-1];
    assign out_vec   = vecs[NUM_STAGES-1];
    assign out_valid = valids[NUM_STAGES-1];

endmodule
