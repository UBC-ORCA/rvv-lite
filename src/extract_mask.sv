module extract_mask 
  #(
    parameter DATA_WIDTH    = 64,
    parameter DW_B          = DATA_WIDTH/8,
    parameter DW_B_BITS     = $clog2(DW_B),
    parameter SEW_WIDTH     = 2,
    parameter ENABLE_64_BIT = 1
  )
  (
    input  logic en,
    input  logic [SEW_WIDTH-1:0] sew,
    input  logic [DW_B_BITS-1:0] reg_off,
    input  logic [DW_B-1:0] vmask_in,
    output logic [DW_B-1:0] vmask_out
  );

  localparam NUM_SEWS = 1 << SEW_WIDTH;
  logic [DW_B-1:0] vmasks[NUM_SEWS];

  genvar j, k;

  for (j = 0; j < NUM_SEWS-1; j++) begin
    localparam W_B = 1 << j;
    for (k = 0; k < DW_B/W_B; k++) begin
      assign vmasks[j][k*W_B +: W_B] = {W_B{vmask_in[reg_off+k]}};
    end
  end

  if (ENABLE_64_BIT) begin
    localparam W_B = 1 << (NUM_SEWS-1);
    for (k = 0; k < DW_B/W_B; k++) begin
      assign vmasks[NUM_SEWS-1][k*W_B +: W_B] = {W_B{vmask_in[reg_off+k]}};
    end
  end else begin
    assign vmasks[NUM_SEWS-1] = 'h0;
  end

  assign vmask_out = en ? vmasks[sew] : {DW_B{1'b1}};

endmodule
