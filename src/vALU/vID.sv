module vID #(
    parameter REQ_BYTE_EN_WIDTH = 8,
    parameter REQ_ADDR_WIDTH    = 5,
    parameter RESP_DATA_WIDTH   = 64,
    parameter ENABLE_64_BIT     = 1
) (
    input                               clk,
    input                               rst,
    input       [   REQ_ADDR_WIDTH-1:0] in_addr,
    input       [                  1:0] in_sew,
    input                               in_valid,
    input       [                 11:0] in_start_idx,
    output reg  [   REQ_ADDR_WIDTH-1:0] out_addr,
    output reg  [  RESP_DATA_WIDTH-1:0] out_vec,
    output reg                          out_valid
);

    reg                         s0_valid, s1_valid, s2_valid, s3_valid, s4_valid;
    reg [RESP_DATA_WIDTH-1:0]   s0_out_vec, s1_out_vec, s2_out_vec, s3_out_vec, s4_out_vec;
    wire[RESP_DATA_WIDTH-1:0]   s0_data [0:3];
    reg [ REQ_ADDR_WIDTH-1:0]   s0_out_addr, s1_out_addr, s2_out_addr, s3_out_addr, s4_out_addr;

    genvar i;
    genvar j;

    generate
        // Assign each element to the appropriate spot in the vector
        for (j = 0; j < 3; j = j + 1) begin
            for (i = 0; i < REQ_BYTE_EN_WIDTH>>j; i = i + 1) begin
                assign s0_data[j][i*(1<<(j+3)) +: (1<<(j+3))] = (i + in_start_idx);
            end
        end
        if (ENABLE_64_BIT) begin
            for (i = 0; i < REQ_BYTE_EN_WIDTH>>3; i = i + 1) begin
                assign s0_data[3][i*64 +: 64] = (i + in_start_idx);
            end
        end else begin
            assign s0_data[3] = 'h0;
        end

    endgenerate

    always @(posedge clk) begin
        if(rst) begin
            s0_out_addr <= 'b0;
            s1_out_addr <= 'b0;
            s2_out_addr <= 'b0;
            s3_out_addr <= 'b0;
            s4_out_addr <= 'b0;
            out_addr    <= 'b0;
          
            s0_out_vec  <= 'b0;
            s1_out_vec  <= 'b0;
            s2_out_vec  <= 'b0;
            s3_out_vec  <= 'b0;
            s4_out_vec  <= 'b0;
            out_vec     <= 'b0;
            
            s0_valid    <= 'b0;
            s1_valid    <= 'b0;
            s2_valid    <= 'b0;
            s3_valid    <= 'b0;
            s4_valid    <= 'b0;
            out_valid   <= 'b0;
        end

        else begin
            s0_valid    <= in_valid;
            s1_valid    <= s0_valid;
            s2_valid    <= s1_valid;
            s3_valid    <= s2_valid;
            s4_valid    <= s3_valid;
            out_valid   <= s4_valid;
          
            s0_out_vec  <= in_valid ? s0_data[in_sew] :'h0;
            s1_out_vec  <= s0_out_vec;
            s2_out_vec  <= s1_out_vec;
            s3_out_vec  <= s2_out_vec;
            s4_out_vec  <= s3_out_vec;
            out_vec     <= s4_out_vec;
          
            s0_out_addr <= in_valid ? in_addr : 'h0;
            s1_out_addr <= s0_out_addr;
            s2_out_addr <= s1_out_addr;
            s3_out_addr <= s2_out_addr;
            s4_out_addr <= s3_out_addr;
            out_addr    <= s4_out_addr;
        end
    end

endmodule