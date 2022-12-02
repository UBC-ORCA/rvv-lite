module avg_unit #(
    parameter DATA_WIDTH    = 64,
    parameter DW_B          = DATA_WIDTH>>3,
    parameter ENABLE_64_BIT = 1
) (
    input                       clk,
    input      [DATA_WIDTH-1:0] vec_in,
    input      [           1:0] sew,
    output reg [      DW_B-1:0] v_d,
    output reg [      DW_B-1:0] v_d1, // v_d and v_d10 are the same for this op
    output reg [DATA_WIDTH-1:0] vec_out
);

reg  [DATA_WIDTH-1:0] vec_out_sew   [0:3];
reg  [      DW_B-1:0] v_d_sew       [0:3];
reg  [      DW_B-1:0] v_d1_sew      [0:3];

genvar i;
integer j;
generate
    for (i = 0; i < 3; i = i + 1) begin
        always @(*) begin
            for (j = 0; j < DW_B >> i; j = j + 1) begin
                vec_out_sew [i][(j<<(i+3)) +: (1<<(i+3))] = vec_in[(j<<(i+3)) + 1 +: ((1 << (i+3)) - 1)];

                v_d_sew     [i][j<<i] = vec_in[(j<<(i+3)) + 1];
                v_d1_sew    [i][j<<i] = vec_in[j<<(i+3)];
            end
        end
    end 
    always @(*) begin
        if (ENABLE_64_BIT) begin
            for (j = 0; j < DW_B >> 3; j = j + 1) begin
                vec_out_sew [3][j*64 +: 64] = vec_in[(j*64 + 1) +: 63];
                v_d_sew     [3][j*8] = vec_in[j*64 + 1];
                v_d1_sew    [3][j*8] = vec_in[j*64];
            end
        end else begin
            vec_out_sew[3]  = 'h0;
            v_d_sew[3]      = 'h0;
            v_d1_sew[3]     = 'h0;
        end
    end

    always @(posedge clk) begin
        vec_out <=  vec_out_sew[sew];

        v_d     <=  v_d_sew [sew];
        v_d1    <=  v_d1_sew[sew];
    end
endgenerate

endmodule