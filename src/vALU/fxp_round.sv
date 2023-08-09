module fxp_round 
  #(
    parameter DATA_WIDTH  = 64,
    parameter DW_B        = DATA_WIDTH/8
  )
  (
    input  logic clk,
    input  logic rst,
    input  logic [2-1:0] vxrm, // comes from vfu "round" port
    input  logic [DW_B-1:0] v_d, // do it like this so we can add directly
    input  logic [DW_B-1:0] v_d1,
    input  logic [DW_B-1:0] v_d10,
    input  logic [DATA_WIDTH-1:0] vec_in,
    input  logic in_valid,
    output logic [DATA_WIDTH-1:0] vec_out
  );

  typedef enum logic [2-1:0] {
    VXRM_RNU = 2'b00,
    VXRM_RNE = 2'b01,
    VXRM_RDN = 2'b10,
    VXRM_ROD = 2'b11
  } vxrm_t;

  logic [DATA_WIDTH-1:0] r_vec;

  genvar i;

  for (i = 0; i < DATA_WIDTH/8; i++) begin
    always_comb begin
      if (in_valid) begin
        unique case (vxrm)
          VXRM_RNU: r_vec[i*8 +: 8]  = 8'(v_d1[i]);            // v[d-1]
          VXRM_RNE: r_vec[i*8 +: 8]  = 8'(v_d[i] & v_d10[i]);  // v[d-1] & (v[d-2:0] != 0 | v[d])
          VXRM_RDN: r_vec[i*8 +: 8]  = 8'b0;                   // 0
          VXRM_ROD: r_vec[i*8 +: 8]  = 8'(~v_d[i] & v_d10[i]); // ~v[d] & v[d-1:0] != 0
        endcase
      end else begin
        r_vec[i*8 +: 8] = 8'b0;
      end
    end
  end

  // logic [DATA_WIDTH-1:0] base_vec;
  // always_ff @(posedge clk) begin
  //   if (rst) begin
  //     base_vec <= 'h0;
  //   end else begin
  //     base_vec <= vec_in;
  //   end
  // end

  // doesn't account for overflow, but this shouldn't be a problem because
  // asub -> can't average to greater than the max value
  // aadd -> can't average to greater than the max value
  // ssrl/a -> can't right shift to greater than max value
  // smul -> think lol

  assign vec_out = vec_in + r_vec;

endmodule
