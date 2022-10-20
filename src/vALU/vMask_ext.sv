`include "vFirst_bit.sv"
`include "vAdd_mask.v"

module vFirst_Popc #(
    parameter REQ_DATA_WIDTH    = 64,
    parameter RESP_DATA_WIDTH   = 64,
    parameter REQ_ADDR_WIDTH    = 32,
    parameter IDX_BITS          = 10,
    parameter DATA_WIDTH_BITS   = 6
) (
    input                               clk,
    input                               rst,
    input       [   REQ_DATA_WIDTH-1:0] in_m0,
    input                               in_valid,
    input       [         IDX_BITS-1:0] in_start_idx,
    input                               in_end,
    input       [   REQ_ADDR_WIDTH-1:0] in_addr,
    input                               in_opSel,
    output reg  [  RESP_DATA_WIDTH-1:0] out_vec,
    output reg  [   REQ_ADDR_WIDTH-1:0] out_addr,
    output reg                          out_valid
    );

    reg     [  RESP_DATA_WIDTH-1:0] idx_out;
    wire    [  RESP_DATA_WIDTH-1:0] w_idx;
    reg     [  RESP_DATA_WIDTH-1:0] found;
    wire                            w_found;

    reg     [  RESP_DATA_WIDTH-1:0] count;
    wire    [  RESP_DATA_WIDTH-1:0] w_count;
    wire    [  RESP_DATA_WIDTH-1:0] w_s1_mask;

    reg     [  RESP_DATA_WIDTH-1:0] s0_mask;
    reg                             s0_valid;
    reg     [         IDX_BITS-1:0] s0_start_idx;
    reg                             s0_end, s1_end, s2_end, s3_end, s4_end;
    reg                             s0_opSel, s1_opSel, s2_opSel, s3_opSel, s4_opSel;
    reg     [   REQ_ADDR_WIDTH-1:0] s0_out_addr, s1_out_addr, s2_out_addr, s3_out_addr, s4_out_addr;

    vFirst_bit #(
        .REQ_DATA_WIDTH(REQ_DATA_WIDTH),
        .RESP_DATA_WIDTH(RESP_DATA_WIDTH),
        .IDX_BITS(IDX_BITS)
        ) vFirst_bit0 (
        .clk        (clk        ),
        .rst        (rst        ),
        .in_valid   (s0_valid & ~(found | w_found)), // stop processing if we found it since we read packs in order
        .in_m0      (s0_mask    ),
        .in_idx     (s0_start_idx),
        .out_vec    (w_idx      ),
        .out_found  (w_found    )
    );

    vAdd_mask vAdd_mask0 (
        .clk        (clk        ),
        .rst        (rst        ),
        .in_valid   (s0_valid   ),
        .in_m0      (s0_mask    ),
        .in_count   (w_count    ),
        .out_vec    (w_count    )
    );

    always @(posedge clk) begin
        if(rst) begin
            s0_mask     <= 'b0;
            s0_valid    <= 'b0;

            idx_out     <= 'b0;
            found       <= 'b0;

            count       <= 'b0;

            out_vec     <= 'b0;
            
            s0_end      <= 'b0;
            s1_end      <= 'b0;
            s2_end      <= 'b0;
            s3_end      <= 'b0;
            s4_end      <= 'b0;
            out_valid   <= 'b0;

            s0_out_addr <= 'b0;
            s1_out_addr <= 'b0;
            s2_out_addr <= 'b0;
            s3_out_addr <= 'b0;
            s4_out_addr <= 'b0;
            out_addr    <= 'b0;

            s0_opSel    <= 'b0;
            s1_opSel    <= 'b0;
            s2_opSel    <= 'b0;
            s3_opSel    <= 'b0;
            s4_opSel    <= 'b0;
        end

        else begin
            s0_mask     <= in_valid ? in_m0 : 'h0;
            s0_valid    <= in_valid | s0_end | s1_end | s2_end | s3_end; 
            s0_start_idx<= in_valid ? in_start_idx << DATA_WIDTH_BITS : 'h0;

            idx_out     <= s4_end ? 'b0 : (w_found ? w_idx : idx_out);
            found       <= s4_end ? 'b0 : (w_found | found);

            count       <= s4_end ? 'b0 : w_count;
            out_vec     <= s4_end ? count : 'b0;

            case ({s4_end, s4_opSel})
                2'b10:  out_vec <= idx_out;
                2'b11:  out_vec <= count;
                default:out_vec <= 'h0;
            endcase

            s0_end      <= in_end & in_valid;
            s1_end      <= s0_end;
            s2_end      <= s1_end;
            s3_end      <= s2_end;
            s4_end      <= s3_end;
            out_valid   <= s4_end;

            s0_out_addr <= in_valid ? in_addr : 'h0;
            s1_out_addr <= s0_out_addr;
            s2_out_addr <= s1_out_addr;
            s3_out_addr <= s2_out_addr;
            s4_out_addr <= s3_out_addr;
            out_addr    <= s4_out_addr;

            s0_opSel    <= in_valid & in_opSel;
            s1_opSel    <= s0_opSel;
            s2_opSel    <= s1_opSel;
            s3_opSel    <= s2_opSel;
            s4_opSel    <= s3_opSel;
        end
    end

endmodule