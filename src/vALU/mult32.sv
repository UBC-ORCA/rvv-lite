module mult32 
  #(
    parameter INPUT_WIDTH = 18
  )
  (
    input  logic clk,
    input  logic rst,
    input  logic signed [INPUT_WIDTH-1:0] in_a0,
    input  logic signed [INPUT_WIDTH-1:0] in_a1,
    input  logic signed [INPUT_WIDTH-1:0] in_b0,
    input  logic signed [INPUT_WIDTH-1:0] in_b1,
    output logic signed [INPUT_WIDTH-1:0] out_mult8_b0,
    output logic signed [INPUT_WIDTH-1:0] out_mult8_b1,
    output logic signed [INPUT_WIDTH-1:0] out_mult8_b2,
    output logic signed [INPUT_WIDTH-1:0] out_mult8_b3,
    output logic signed [INPUT_WIDTH*2-2:0] out_mult16_p0,
    output logic signed [INPUT_WIDTH*2-2:0] out_mult16_p1,
    output logic signed [INPUT_WIDTH*2+30:0] out_mult32
  );

  logic signed [INPUT_WIDTH-1:0] A[2];
  logic signed [INPUT_WIDTH-1:0] B[2];
  logic signed [1+16-1:0] prods8[2][2];
  logic signed [1+32-1:0] prods16[2][2];
  logic signed [1+1+64-1:0] prod32;

  always_comb begin
    A[0] = in_a0;
    A[1] = in_a1;
    B[0] = in_b0;
    B[1] = in_b1;
  end

  always_ff @(posedge clk) begin
    for (int j = 0; j < 2; j++) begin
      for (int k = 0; k < 2; k++) begin
        prods8[j][k] <= A[j][k*(1+8) +: (1+8)] * B[j][k*(1+8) +: (1+8)];

        if (rst)
          prods8[j][k] <= 'b0;
      end
    end
  end

  always_ff @(posedge clk) begin
    for (int i = 0; i < 2; i++) begin
      for (int j = 0; j < 2; j++) begin
        prods16[i][j] <= A[i] * B[j];

        if (rst)
          prods16[i][j] <= 'b0;
      end
    end
  end

  always_comb begin
    prod32 = {(1+64)'(prods16[0][0]) << 32} + 
             {(1+64)'(prods16[0][1]) << 16} + 
             {(1+64)'(prods16[1][0]) << 16} + 
             {(1+64)'(prods16[1][1]) <<  0};
  end

  always_ff @(posedge clk) begin
    out_mult8_b0  <= prods8[0][0];
    out_mult8_b1  <= prods8[0][1];
    out_mult8_b2  <= prods8[1][0];
    out_mult8_b3  <= prods8[1][1];
    out_mult16_p0 <= prods16[0][0];
    out_mult16_p1 <= prods16[1][1];
    out_mult32    <= prod32;

    if (rst) begin
      out_mult8_b0  <= 'b0;
      out_mult8_b1  <= 'b0;
      out_mult8_b2  <= 'b0;
      out_mult8_b3  <= 'b0;
      out_mult16_p0 <= 'b0;
      out_mult16_p1 <= 'b0;
      out_mult32    <= 'b0;
    end
  end

endmodule
