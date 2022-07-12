module vID #(
    parameter REQ_BYTE_EN_WIDTH = 8,
    parameter REQ_ADDR_WIDTH    = 32,
    parameter RESP_DATA_WIDTH   = 64
) (
    input                               clk,
    input                               rst,
    input       [   REQ_ADDR_WIDTH-1:0] in_addr,
    input       [                  2:0] in_sew,
    input                               in_valid,
    input       [                  2:0] in_start_idx,
    input       [REQ_BYTE_EN_WIDTH-1:0] in_mask,
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
        // FIXME lmul < 1?
        for (j = 0; j < 4; j = j + 1) begin
            for (i = 0; i < REQ_BYTE_EN_WIDTH>>j; i = i + 1) begin
                assign s0_data[j][((i+1)<<(j+3))-1:i<<(j+3)] = {(8<<j){(in_mask[i])}} & (i + in_start_idx);
            end
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
//          s2_valid    <= s1_valid;
//          s3_valid    <= s2_valid;
            s4_valid    <= s1_valid;
            out_valid   <= s4_valid;
          
            s0_out_vec  <= {RESP_DATA_WIDTH{in_valid}} & s0_data[in_sew];
            s1_out_vec  <= s0_out_vec;
//          s2_out_vec  <= s1_out_vec;
//          s3_out_vec  <= s2_out_vec;
            s4_out_vec  <= s1_out_vec;
            out_vec     <= s4_out_vec;
          
            s0_out_addr <= {REQ_ADDR_WIDTH{in_valid}} & in_addr;
            s1_out_addr <= s0_out_addr;
//          s2_out_addr <= s1_out_addr;
//          s3_out_addr <= s2_out_addr;
            s4_out_addr <= s1_out_addr;
            out_addr    <= s4_out_addr;
        end
    end

endmodule