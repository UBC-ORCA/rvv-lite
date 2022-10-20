`include "vRedAndOrXor_unit_block.v"
`include "vRedSum_Min_Max_unit_block.v"

`define MIN(a,b) {(a > b) ? b : a}

module vReduction #(
    parameter REQ_DATA_WIDTH    = 64,
    parameter REQ_BE_WIDTH      = REQ_DATA_WIDTH/8,
    parameter RESP_DATA_WIDTH   = 64,
    parameter REQ_ADDR_WIDTH    = 32,
    parameter OPSEL_WIDTH       = 3 ,
    parameter SEW_WIDTH         = 2 ,
    parameter ENABLE_64_BIT     = 0
) (
    input                               clk,
    input                               rst,
    input       [ REQ_DATA_WIDTH-1:0]   in_vec0,
    input       [ REQ_DATA_WIDTH-1:0]   in_vec1,
    input                               in_valid,
    input                               in_lop_sum,
    input                               in_start,
    input                               in_end,
    input       [    OPSEL_WIDTH-1:0]   in_opSel, //01=and,10=or,11=xor
    input       [      SEW_WIDTH-1:0]   in_sew,
    input       [ REQ_ADDR_WIDTH-1:0]   in_addr,
    output reg  [ REQ_ADDR_WIDTH-1:0]   out_addr,
    output reg  [RESP_DATA_WIDTH-1:0]   out_vec,
    output reg                          out_valid,
    output reg  [   REQ_BE_WIDTH-1:0]   out_be
);
    
    reg [ REQ_DATA_WIDTH-1:0]   s0_vec0;
    reg [    OPSEL_WIDTH-1:0]   s0_opSel, s1_opSel, s2_opSel, s3_opSel;
    reg [      SEW_WIDTH-1:0]   s0_sew, s1_sew, s2_sew, s3_sew, s4_sew;
    reg                         s0_start, s1_start, s2_start, s3_start;
    reg                         s0_end, s1_end, s2_end, s3_end, s4_end;
    reg                         s0_valid, s1_valid, s2_valid, s3_valid;
    reg [ REQ_DATA_WIDTH-1:0]   s0_vec1, s1_vec1, s2_vec1, s3_vec1;
    reg [ REQ_ADDR_WIDTH-1:0]   s0_out_addr, s1_out_addr, s2_out_addr, s3_out_addr, s4_out_addr;

    wire [REQ_DATA_WIDTH-1:0]   s1_lopOut, s2_lopOut, s3_lopOut, s4_lopOut;
    reg                         s0_lop_sum, s1_lop_sum, s2_lop_sum, s3_lop_sum, s4_lop_sum;
    wire [REQ_DATA_WIDTH-1:0]   s1_sumOut, s2_sumOut, s3_sumOut, s4_sumOut;
    reg  [  REQ_BE_WIDTH-1:0]   s4_be;

    vRedAndOrXor_unit_block # (
        .REQ_DATA_WIDTH (64),
        .ENABLE_64_BIT(ENABLE_64_BIT)
    ) lop64 (
        .clk        (clk            ),
        .rst        (rst            ),
        .in_vec0    ({s3_lopOut,(s3_start ? s3_vec1 : s4_lopOut)}),
        .in_en      (1'b1           ),
        .in_opSel   (s3_opSel[1:0]  ),
        .out_vec    (s4_lopOut      )
    );

    if (ENABLE_64_BIT) begin
        vRedAndOrXor_unit_block # (
            .REQ_DATA_WIDTH (32)
        ) lop32 (
            .clk        (clk            ),
            .rst        (rst            ),
            .in_vec0    (s0_vec0        ),
            .in_en      (s0_sew < 2'b11 & s0_valid),
            .in_opSel   (s0_opSel[1:0]  ),
            .out_vec    (s1_lopOut      )
        );
    end else begin
        vRedAndOrXor_unit_block # (
            .REQ_DATA_WIDTH (32)
        ) lop32 (
            .clk        (clk            ),
            .rst        (rst            ),
            .in_vec0    (s0_vec0        ),
            .in_en      (s0_valid       ),
            .in_opSel   (s0_opSel[1:0]  ),
            .out_vec    (s1_lopOut      )
        );
    end
    

    vRedAndOrXor_unit_block # (
        .REQ_DATA_WIDTH (16)
    ) lop16 (
        .clk        (clk            ),
        .rst        (rst            ),
        .in_vec0    (s1_lopOut      ),
        .in_en      (s1_sew < 2'b10 & s1_valid),
        .in_opSel   (s1_opSel[1:0]  ),
        .out_vec    (s2_lopOut      )
    );


    vRedAndOrXor_unit_block # (
        .REQ_DATA_WIDTH (8)
    ) lop8 (
        .clk        (clk            ),
        .rst        (rst            ),
        .in_vec0    (s2_lopOut      ),
        .in_en      (s2_sew < 2'b01 & s2_valid),
        .in_opSel   (s2_opSel[1:0]  ),
        .out_vec    (s3_lopOut      )
    );

    vRedSum_min_max_unit_block # (
        .REQ_DATA_WIDTH (64),
        .ENABLE_64_BIT(ENABLE_64_BIT)
    ) sum64 (
        .clk        (clk                                    ),
        .rst        (rst                                    ),
        .vec0       ({s3_sumOut,(s3_start ? s3_vec1 : s4_sumOut)}),
        .sew        (s3_sew                                 ),
        .en         (s3_valid                               ),
        .opSel      (s3_opSel[2:1]                          ),
        .out_vec    (s4_sumOut                              )
    );

    if (ENABLE_64_BIT) begin
        vRedSum_min_max_unit_block # (
            .REQ_DATA_WIDTH (32)
        ) sum32 (
            .clk    (clk            ),
            .rst    (rst            ),
            .vec0   (s0_vec0        ),
            .sew    (s0_sew         ),
            .en     (s0_sew < 2'b11 & s0_valid),
            .opSel  (s0_opSel[2:1]  ),
            .out_vec(s1_sumOut      )
        );
    end else begin
        vRedSum_min_max_unit_block # (
            .REQ_DATA_WIDTH (32)
        ) sum32 (
            .clk    (clk            ),
            .rst    (rst            ),
            .vec0   (s0_vec0        ),
            .sew    (s0_sew         ),
            .en     (s0_valid       ),
            .opSel  (s0_opSel[2:1]  ),
            .out_vec(s1_sumOut      )
        );
    end

    vRedSum_min_max_unit_block # (
        .REQ_DATA_WIDTH (16)
    ) sum16 (
        .clk    (clk            ),
        .rst    (rst            ),
        .vec0   (s1_sumOut      ),
        .sew    (s1_sew         ),
        .en     (s1_sew < 2'b10 & s1_valid),
        .opSel  (s1_opSel[2:1]  ),
        .out_vec(s2_sumOut      )
    );


    vRedSum_min_max_unit_block # (
        .REQ_DATA_WIDTH (8)
    ) sum8 (
        .clk    (clk            ),
        .rst    (rst            ),
        .vec0   (s2_sumOut      ),
        .sew    (s2_sew         ),
        .en     (s2_sew < 2'b01 & s2_valid),
        .opSel  (s2_opSel[2:1]  ),
        .out_vec(s3_sumOut      )
    );

    always @(posedge clk) begin
        if(rst) begin
            s0_vec0     <= 'b0;
            s0_opSel    <= 'b0;
            s1_opSel    <= 'b0;
            s2_opSel    <= 'b0;
            s3_opSel    <= 'b0;

            s0_sew      <= 'b0;
            s1_sew      <= 'b0;
            s2_sew      <= 'b0;
            s3_sew      <= 'b0;

            s0_start    <= 'b0;
            s1_start    <= 'b0;
            s2_start    <= 'b0;
            s3_start    <= 'b0;

            s0_end      <= 'b0;
            s1_end      <= 'b0;
            s2_end      <= 'b0;
            s3_end      <= 'b0;
            s4_end      <= 'b0;
            out_valid   <= 'b0;

            s0_vec1     <= 'b0;
            s1_vec1     <= 'b0;
            s2_vec1     <= 'b0;
            s3_vec1     <= 'b0;
            out_vec     <= 'b0;

            s0_out_addr <= 'b0;
            s1_out_addr <= 'b0;
            s2_out_addr <= 'b0;
            s3_out_addr <= 'b0;
            s4_out_addr <= 'b0;
            out_addr    <= 'b0;

            s0_lop_sum  <= 'b0;
            s1_lop_sum  <= 'b0;
            s2_lop_sum  <= 'b0;
            s3_lop_sum  <= 'b0;
            s4_lop_sum  <= 'b0;

            s0_valid    <= 'b0;
            s1_valid    <= 'b0;
            s2_valid    <= 'b0;
            s3_valid    <= 'b0;
        end 
        else begin
            s0_vec0     <= in_valid ? in_vec0 : 'h0; //     & {REQ_DATA_WIDTH{in_valid}};
            s0_opSel    <= in_valid ? in_opSel : 'h0; // & {OPSEL_WIDTH{in_valid}};
            s1_opSel    <= s0_opSel;
            s2_opSel    <= s1_opSel;
            s3_opSel    <= s2_opSel;

            s0_sew      <= in_valid ? in_sew : 'h0; //  & {SEW_WIDTH{in_valid}};
            s1_sew      <= s0_sew;
            s2_sew      <= s1_sew;
            s3_sew      <= s2_sew;

            s0_start    <= in_start & in_valid;
            s1_start    <= s0_start;
            s2_start    <= s1_start;
            s3_start    <= s2_start;

            s0_vec1     <= in_vec1;
            s1_vec1     <= s0_vec1;
            s2_vec1     <= s1_vec1;
            s3_vec1     <= s2_vec1;

            s0_end      <= in_end   & in_valid;
            s1_end      <= s0_end;
            s2_end      <= s1_end;
            s3_end      <= s2_end;
            s4_end      <= s3_end;
            
            out_valid   <= s4_end;
            case ({s4_end, s4_lop_sum})
                2'b11: out_vec <= s4_lopOut;
                2'b10: out_vec <= s4_sumOut;
                default:out_vec <= 'h0;
            endcase

            s0_out_addr <= in_valid ? in_addr : 'b0; //     & {REQ_ADDR_WIDTH{in_valid}};
            s1_out_addr <= s0_out_addr;
            s2_out_addr <= s1_out_addr;
            s3_out_addr <= s2_out_addr;
            s4_out_addr <= s3_out_addr;
            out_addr    <= s4_out_addr;

            out_be      <= s4_be;

            s0_lop_sum  <= in_valid & in_lop_sum;
            s1_lop_sum  <= s0_lop_sum;
            s2_lop_sum  <= s1_lop_sum;
            s3_lop_sum  <= s2_lop_sum;
            s4_lop_sum  <= s3_lop_sum;

            s0_valid    <= in_valid;
            s1_valid    <= s0_valid;
            s2_valid    <= s1_valid;
            s3_valid    <= s2_valid;
        end
    end

    always @(*) begin
        case ({s4_end, s4_sew})
            3'b100: s4_be = 'h1;
            3'b101: s4_be = 'h3;
            3'b110: s4_be = 'h7;
            3'b111: begin
                if (ENABLE_64_BIT) begin
                    s4_be = 'hF;
                end else begin
                    s4_be = 'h0;
                end
            end
            default:s4_be = 'h0;
        endcase
    end

endmodule