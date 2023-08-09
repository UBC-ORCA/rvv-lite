module avg_unit 
  #(
    parameter DATA_WIDTH    = 64,
    parameter DW_B          = DATA_WIDTH/8,
    parameter SEW_WIDTH     = 2,
    parameter ENABLE_64_BIT = 1
  ) 
  (
    input  logic clk,
    input  logic [DATA_WIDTH-1:0] vec_in,
    input  logic [SEW_WIDTH-1:0] sew,
    output logic [DW_B-1:0] v_d,
    output logic [DW_B-1:0] v_d1, // v_d and v_d10 are the same for this op
    output logic [DATA_WIDTH-1:0] vec_out
  );

  localparam NUM_SEWS = 1 << SEW_WIDTH;
  logic [DATA_WIDTH-1:0] vec_out_sew [NUM_SEWS];
  logic [DW_B-1:0] v_d_sew [NUM_SEWS];
  logic [DW_B-1:0] v_d1_sew [NUM_SEWS];

  genvar j, k;

  for (j = 0; j < NUM_SEWS-1; j++) begin
    localparam W_B = 1 << j;
    localparam W = 8*W_B;
    for (k = 0; k < DW_B/W_B; k++) begin
      always_comb begin
        vec_out_sew[j][k*W +: W]  = vec_in[k*W +: W]/2;
        v_d_sew [j][k*W_B +: W_B] = (W_B)'(vec_in[k*W+1 +: 1]);
        v_d1_sew[j][k*W_B +: W_B] = (W_B)'(vec_in[k*W   +: 1]);
      end
    end
  end 

  if (ENABLE_64_BIT) begin
    localparam W_B = 1 << (NUM_SEWS-1);
    localparam W = 8*W_B;
    for (k = 0; k < DW_B/W_B; k++) begin
      always_comb begin
        vec_out_sew[NUM_SEWS-1][k*W +: W]  = vec_in[k*W +: W]/2;
        v_d_sew [NUM_SEWS-1][k*W_B +: W_B] = (W_B)'(vec_in[k*W+1 +: 1]);
        v_d1_sew[NUM_SEWS-1][k*W_B +: W_B] = (W_B)'(vec_in[k*W   +: 1]);
      end
    end
  end else begin
    always_comb begin
      vec_out_sew[NUM_SEWS-1] = 'h0;
      v_d_sew[NUM_SEWS-1] = 'h0;
      v_d1_sew[NUM_SEWS-1] = 'h0;
    end
  end

  always_ff @(posedge clk) begin
    vec_out <= vec_out_sew[sew];
    v_d <= v_d_sew[sew];
    v_d1 <= v_d1_sew[sew];
  end

endmodule
