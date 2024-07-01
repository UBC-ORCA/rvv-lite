module extract_mask 
  #(
    parameter VLEN          = 16384,
    parameter DATA_WIDTH    = 64,
    parameter ADDR_WIDTH    = 5,    // this gives us 32 vectors
    parameter DW_B          = DATA_WIDTH/8,
    parameter DW_B_BITS     = $clog2(DW_B),
    parameter SEW_WIDTH     = 2,
    parameter OFF_BITS      = $clog2(VLEN/DATA_WIDTH),
    parameter ENABLE_64_BIT = 1
  )
  (
    input  logic [SEW_WIDTH-1:0] sew,
    input  logic [OFF_BITS-1:0] dw_offset,
    input  logic mask_en,
    input  logic [DATA_WIDTH-1:0] mask_data,
    output logic [DW_B-1:0] mask_be
  );

  localparam NUM_SEWS = 1 << SEW_WIDTH;
  logic [DW_B-1:0] mask_bes[NUM_SEWS];
  logic [OFF_BITS+DW_B_BITS-1:0] b;
  logic [OFF_BITS-1:0] y;
  logic [DW_B_BITS-1:0] x;
  logic [DW_B-1:0] d;

  genvar j, o;

  for (j = 0; j < NUM_SEWS-1; j++) begin
    localparam W_B = 1 << j;
    for (o = 0; o < DW_B/W_B; o++) begin
      always_comb begin
        b = (OFF_BITS+DW_B_BITS)'(dw_offset) * DW_B/W_B;
        {y,x} = (OFF_BITS+DW_B_BITS)'(b+o);
        d = mask_data[y*DW_B +: DW_B];
        mask_bes[j][o*W_B +: W_B] = {W_B{d[x]}};
      end
    end
  end

  if (ENABLE_64_BIT) begin
    localparam W_B = 1 << (NUM_SEWS-1);
    for (o = 0; o < DW_B/W_B; o++) begin
      always_comb begin
        b = (OFF_BITS+DW_B_BITS)'(dw_offset) * DW_B/W_B;
        {y,x} = (OFF_BITS+DW_B_BITS)'(b+o);
        d = mask_data[y*DW_B +: DW_B];
        mask_bes[NUM_SEWS-1][o*W_B +: W_B] = {W_B{d[x]}};
      end
    end
  end else begin
    assign mask_bes[NUM_SEWS-1] = 'h0;
  end

  assign mask_be = mask_en ? mask_bes[sew] : {DW_B{1'b1}};

endmodule
