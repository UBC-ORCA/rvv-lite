module generate_be 
  #(
    parameter AVL_WIDTH     = 11,
    parameter DATA_WIDTH    = 64,
    parameter DW_B          = DATA_WIDTH/8,
    parameter DW_B_BITS     = $clog2(DW_B),
    parameter SEW_WIDTH     = 2,
    parameter ENABLE_64_BIT = 1
  ) 
  (
    input  logic [AVL_WIDTH-1:0] avl,
    input  logic [SEW_WIDTH-1:0] sew,
    input  logic [AVL_WIDTH-1-1:0] reg_count,
    output logic [DW_B-1:0] avl_be
  );

  localparam NUM_SEWS = 1 << SEW_WIDTH;
  logic [DW_B-1:0] avl_bes [NUM_SEWS];

  genvar j, k;

  // Generate mask byte enable based on SEW and current index in vector
  for (j = 0; j < NUM_SEWS-1; j++) begin
    localparam W_B = 1 << j;
    for (k = 0; k < DW_B/W_B; k++) begin
      assign avl_bes[j][k*W_B +: W_B] = reg_count*DW_B/W_B + k < avl ? {W_B{1'b1}} : {W_B{1'b0}};
    end
  end

  if (ENABLE_64_BIT) begin
    localparam W_B = 1 << (NUM_SEWS-1);
    for (k = 0; k < DW_B/W_B; k++) begin
      assign avl_bes[NUM_SEWS-1][k*W_B +: W_B] = reg_count*DW_B/W_B + k < avl ? {W_B{1'b1}} : {W_B{1'b0}};
    end
  end else begin
    assign avl_bes[NUM_SEWS-1] = 'h0;
  end

  assign avl_be = avl_bes[sew];

endmodule

