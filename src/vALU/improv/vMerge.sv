module vMerge 
  #(
    parameter REQ_DATA_WIDTH    = 64,
    parameter RESP_DATA_WIDTH   = 64,
    parameter REQ_ADDR_WIDTH    = 32,
    parameter MASK_WIDTH        = 8
  ) 
  (
    input  logic clk,
    input  logic rst,
    input  logic in_valid,
    input  logic [REQ_ADDR_WIDTH-1:0] in_addr,
    input  logic [MASK_WIDTH-1:0] in_mask,
    input  logic [REQ_DATA_WIDTH-1:0] in_vec0,
    input  logic [REQ_DATA_WIDTH-1:0] in_vec1,
    output logic out_valid,
    output logic [REQ_ADDR_WIDTH-1:0] out_addr,
    output logic [RESP_DATA_WIDTH-1:0] out_vec
  );

  localparam NUM_STAGES = 6;
  logic [REQ_ADDR_WIDTH-1:0] addrs[NUM_STAGES];
  logic [REQ_DATA_WIDTH-1:0] vecs[NUM_STAGES];
  logic valids[NUM_STAGES];

  logic [REQ_DATA_WIDTH-1:0] vec;
  
  always_comb begin
    for (int i = 0; i < REQ_DATA_WIDTH/8; i++) 
      vec[8*i +: 8] <= in_mask[i] ? in_vec1[8*i +: 8] : in_vec0[8*i +: 8];
  end

  always_ff @(posedge clk) begin
    addrs[0]  <= in_valid ? in_addr : REQ_ADDR_WIDTH'(0);
    vecs[0]   <= in_valid ? vec : REQ_DATA_WIDTH'(0);
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
