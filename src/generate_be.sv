module generate_be 
  #(
    parameter VLEN          = 16384,
    parameter AVL_WIDTH     = $clog2(VLEN/8)+1,
    parameter DATA_WIDTH    = 64,
    parameter DW_B          = DATA_WIDTH/8,
    parameter DW_B_BITS     = $clog2(DW_B),
    parameter SEW_WIDTH     = 2,
    parameter ENABLE_64_BIT = 1
  ) 
  (
    input  logic [SEW_WIDTH-1:0] sew,
    input  logic [AVL_WIDTH-1:0] avl,
    input  logic [AVL_WIDTH-1:0] avl_dw_offset,
    output logic [DW_B-1:0] avl_be
  );

  localparam NUM_SEWS = 1 << SEW_WIDTH;
  logic [DW_B-1:0] avl_bes [NUM_SEWS];
  logic [AVL_WIDTH-1:0] b;

  genvar j, o;

  // Generate mask byte enable based on SEW and current index in vector
  for (j = 0; j < NUM_SEWS-1; j++) begin
    localparam W_B = 1 << j;
    for (o = 0; o < DW_B/W_B; o++) begin
      always_comb begin
        b = (AVL_WIDTH)'(avl_dw_offset) * DW_B/W_B;
        avl_bes[j][o*W_B +: W_B] = (AVL_WIDTH)'(b+o) < avl ? {W_B{1'b1}} : {W_B{1'b0}};
      end
    end
  end

  if (ENABLE_64_BIT) begin
    localparam W_B = 1 << (NUM_SEWS-1);
    for (o = 0; o < DW_B/W_B; o++) begin
      always_comb begin
        b = (AVL_WIDTH)'(avl_dw_offset) * DW_B/W_B;
        avl_bes[NUM_SEWS-1][o*W_B +: W_B] = (AVL_WIDTH)'(b+o) < avl ? {W_B{1'b1}} : {W_B{1'b0}};
      end
    end
  end else begin
    assign avl_bes[NUM_SEWS-1] = 'h0;
  end

  assign avl_be = avl_bes[sew];

endmodule
