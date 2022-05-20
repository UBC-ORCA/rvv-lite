`include "vAdd_min_max.v"
`include "vAndOrXor.v"
`include "vMerge.v"
`include "vMOP.v"
`include "vMove.v"
`include "vMul.v"
`include "vNarrow.v"
`include "vPopc.v"
`include "vRedAndOrXor.v"
`include "vRedSum_min_max.v"
`include "vSlide.v"
`include "vWiden.v"
`include "vMinMaxSelector.v"
`include "vAdd_unit_block.v"

module vALU #(
    parameter REQ_FUNC_ID_WIDTH = 6 ,
    parameter REQ_DATA_WIDTH    = 64,
    parameter RESP_DATA_WIDTH   = 64,
    parameter SEW_WIDTH         = 2 ,
    parameter REQ_ADDR_WIDTH    = 32,
    parameter REQ_VL_WIDTH      = 8 ,
    parameter REQ_BYTE_EN_WIDTH = REQ_DATA_WIDTH/8,
    parameter MIN_MAX_ENABLE    = 1 ,
    parameter AND_OR_XOR_ENABLE = 1 ,
    parameter ADD_SUB_ENABLE    = 1 ,
    parameter SHIFT_ENABLE      = 1 ,
    parameter MULT_ENABLE       = 1 ,
    parameter MULT64_ENABLE     = 1 ,
    parameter SLIDE_ENABLE      = 1 ,
    parameter WIDEN_ENABLE      = 1 ,
    parameter NARROW_ENABLE     = 1 ,
    parameter MASK_ENABLE       = 1 ,
    parameter REDUCTION_ENABLE  = 1 ,
    parameter VEC_MOVE_ENABLE   = 1
) (
    input                              clk         ,
    input                              rst         ,
    input                              req_valid   ,
    input      [                  2:0] req_op_mnr  ,
    input      [REQ_FUNC_ID_WIDTH-1:0] req_func_id ,
    input      [        SEW_WIDTH-1:0] req_sew     ,
    input      [   REQ_DATA_WIDTH-1:0] req_data0   ,
    input      [   REQ_DATA_WIDTH-1:0] req_data1   ,
    input      [   REQ_ADDR_WIDTH-1:0] req_addr    ,
    input      [REQ_BYTE_EN_WIDTH-1:0] req_be      ,
    input      [     REQ_VL_WIDTH-1:0] req_vl      ,
    input                              req_start   ,
    input                              req_end     ,
    input                              req_mask    ,
    output reg                         resp_valid  ,
    output reg [  RESP_DATA_WIDTH-1:0] resp_data   ,
    output                             req_ready   ,
    output reg [   REQ_ADDR_WIDTH-1:0] req_addr_out,
    output reg [     REQ_VL_WIDTH-1:0] req_vl_out  ,
    output reg [REQ_BYTE_EN_WIDTH-1:0] req_be_out
);

reg [   REQ_ADDR_WIDTH-1:0]     s0_addr, s1_addr, s2_addr, s3_addr, s4_addr, s5_addr;
reg [REQ_BYTE_EN_WIDTH-1:0]     s0_be, s1_be, s2_be, s3_be, s4_be, s5_be;
reg [     REQ_VL_WIDTH-1:0]     s0_vl, s1_vl, s2_vl, s3_vl, s4_vl, s5_vl;
reg [REQ_FUNC_ID_WIDTH-1:0]     s0_func_id, s1_func_id, s2_func_id, s3_func_id, s4_func_id;
reg                             turn;

wire [   REQ_DATA_WIDTH-1:0]    vWiden_in0, vWiden_in1;
wire [   REQ_DATA_WIDTH-1:0]    vAdd_in0, vAdd_in1, vMul_in0, vMul_in1, vSlide_in1;
wire [   REQ_DATA_WIDTH-1:0]    vAdd_outVec, vAndOrXor_outVec, vMul_outVec, vSlide_outVec, vNarrow_outVec;
wire [                  1:0]    vAndOrXor_opSel, vMul_opSel, vAdd_opSel;
wire [   REQ_DATA_WIDTH-1:0]    vMul_vec1      ;
wire [   REQ_DATA_WIDTH-1:0]    vShift_mult    ;
wire [                  6:0]    vShift_cmpl    ;
wire [                  1:0]    vSlide_sew, vWiden_sew, vAdd_sew, vMul_sew;
wire [REQ_BYTE_EN_WIDTH-1:0]    vSlide_outBe, vWiden_be, vNarrow_be;
wire                            vAdd_outValid, vAndOrXor_outValid, vMul_outValid, vSlide_outValid, vNarrow_outValid;
wire                            vMinMax_opSel, vRightShift_opSel, vSlide_opSel;
wire                            vAdd_en, vMinMax_en, vAndOrXor_en, vMul_en, vSlide_en;
wire                            vNarrow_en, vWiden_en;
wire                            vSigned_op     ;
wire                            vSlide_insert  ; //TODO: assign something

wire [  RESP_DATA_WIDTH-1:0]    vMerge_outVec, vMOP_outVec, vPopc_outVec, vRedAndOrXor_outVec, vRedSum_min_max_outVec, vMove_outVec;
wire                            vMerge_outValid, vMOP_outValid, vPopc_outValid, vRedAndOrXor_outValid, vRedSum_min_max_outValid, vMove_outValid;
wire [                  9:0]    vMOP_opSel, vRedAndOrXor_opSel, vRedSum_min_max_opSel;
wire                            vMerge_en, vMOP_en, vPopc_en, vRedAndOrXor_en, vRedSum_min_max_en, vMove_en;

wire [   REQ_ADDR_WIDTH-1:0]    vMove_outAddr, vAdd_outAddr, vAndOrXor_outAddr, vMul_outAddr, vSlide_outAddr, vNarrow_outAddr, vMerge_outAddr,
                                vMOP_outAddr, vPopc_outAddr, vRedAndOrXor_outAddr, vRedSum_min_max_outAddr;

// TODO: Update enable signals for FP instr later
assign vAdd_en              = req_valid & ((req_func_id[5:3] == 3'b000) || (req_func_id[5:2] == 4'b1100));
assign vAndOrXor_en         = req_valid & (req_func_id[5:2] == 4'b0010);
assign vMinMax_en           = req_valid & (req_func_id[5:2] == 4'b0001);
assign vMul_en              = req_valid & ((req_func_id[5:2] == 4'b1001) | (req_func_id[5:2] == 4'b1010) | (req_func_id == 6'b110101) | (req_func_id[5:2] == 4'b1110));
assign vSlide_en            = req_valid & (req_func_id[5:1] == 5'b00111);
assign vMove_en             = req_valid & (req_func_id == 6'b010111) & req_mask;

assign vNarrow_en           = req_valid & (req_func_id == 6'b101100);
assign vMerge_en            = req_valid & (req_func_id == 6'b010111) & ~req_mask;
assign vMOP_en              = 0; // req_valid & (req_func_id == 'h3F); // TODO
assign vPopc_en             = req_valid & (req_func_id == 'h10) & (req_data0 == 'h10); // Popc uses VWXUNARY0
assign vRedAndOrXor_en      = req_valid & (req_func_id == 6'b000001 | req_func_id == 6'b000010 | req_func_id == 6'b000011) & (req_op_mnr == 3'h2);
assign vRedSum_min_max_en   = req_valid & ((req_func_id == 6'b000000 | req_func_id == 6'b000100 | req_func_id == 6'b000101
                                | req_func_id == 6'b000110   | req_func_id == 6'b000111 ) & (req_op_mnr == 3'h2));

assign vMoveXS_en           = req_valid & (req_func_id == 'h10) & (req_data0 == 'h0) & (req_op_mnr == 3'h2);
assign vMoveSX_en           = req_valid & (req_func_id == 'h10) & (req_data0 == 'h0) & (req_op_mnr == 3'h2);

assign vSlide_sew           = req_data1[3] ? (req_sew + 2'b11) : (req_data1[2] ? (req_sew + 2'b10) : (req_data1[1] ? (req_sew + 2'b01) : (req_sew)));
assign vSlide_insert        = 1;
assign req_ready            = 1'b1; //TODO: contr000110 | ol

assign vAdd_sew             = vWiden_en ? vWiden_sew : req_sew;
assign vMul_sew             = vWiden_en ? vWiden_sew : req_sew;

assign vAdd_in0             = vWiden_en ? vWiden_in0 : req_data0;
assign vAdd_in1             = vWiden_en ? vWiden_in1 : req_data1;
assign vMul_in0             = vWiden_en ? vWiden_in0 : req_data0;
assign vMul_in1             = vWiden_en ? vWiden_in1 : vMul_vec1;

assign vSlide_in1           = vSlide_insert ? req_data1 : 'b0;

assign vRightShift_opSel    = req_func_id[0];
assign vMinMax_opSel        = req_func_id[1];
assign vSigned_op           = req_func_id[0];
assign vAndOrXor_opSel      = req_func_id[1:0];
assign vAdd_opSel           = req_func_id[2] ? 2'b10 : req_func_id[1:0];
assign vSlide_opSel         = req_func_id[0];
assign vMOP_opSel           = req_func_id[3:0];
assign vRedAndOrXor_opSel   = req_func_id[1:0];
assign vRedSum_min_max_opSel= req_func_id[0];

generate
    if(WIDEN_ENABLE) begin
        assign vWiden_en    = (req_func_id[5:2] == 4'b1100 || req_func_id[5:2] == 4'b1110);

        vWiden vWiden_0 (
            .in_vec0    (req_data0  ),
            .in_vec1    (req_data1  ),
            .in_turn    (turn       ),
            .in_be      (req_be     ),
            .in_signed  (vSigned_op ),
            .in_sew     (req_sew    ),
            .out_be     (vWiden_be  ),
            .out_vec0   (vWiden_in0 ),
            .out_vec1   (vWiden_in1 ),
            .out_sew    (vWiden_sew )
        );
    end
    else begin
        assign vWiden_en    = 'b0;
        assign vWiden_be    = 'b0;
        assign vWiden_in0   = 'b0;
        assign vWiden_in1   = 'b0;
        assign vWiden_sew   = 'b0;
    end
endgenerate

generate
    if(NARROW_ENABLE) begin
        vNarrow vNarrow_0 (
            .clk        (clk                ),
            .rst        (rst                ),
            .in_vec0    (req_data0          ),
            .in_vec1    (req_data1          ),
            .in_valid   (vNarrow_en         ),
            .in_sew     (req_sew            ),
            .in_turn    (turn               ),
            .in_be      (req_be             ),
            .in_addr    (req_addr           ),
            .out_be     (vNarrow_be         ),
            .out_vec    (vNarrow_outVec     ),
            .out_addr   (vNarrow_outAddr    ),
            .out_valid  (vNarrow_outValid   )
        );
    end
    else begin
        assign vNarrow_be       = 'b0;
        assign vNarrow_outVec   = 'b0;
        assign vNarrow_outValid = 'b0;
        assign vNarrow_outAddr  = 'b0;
    end
endgenerate


generate
    if(SHIFT_ENABLE) begin
        assign vShift_cmpl = req_sew[1] ? (req_sew[0] ? 7'd64 : 7'd32) : (req_sew[0] ? 7'd16 : 7'd8);
        assign vShift_mult = (req_func_id[5:2] == 4'b1010) ? 2**(vShift_cmpl-req_data1[6:0]) : 2**(req_data1[6:0]);
        assign vMul_vec1   = (req_func_id[5:2] == 4'b1001) ? req_data1 : (req_sew[1] ? (req_sew[0] ? (vShift_mult) : ({2{vShift_mult[31:0]}})) : (req_sew[0] ? ({4{vShift_mult[15:0]}}) : ({8{vShift_mult[7:0]}})));
        assign vMul_opSel  = (req_func_id[5:2] == 4'b1001) ? req_func_id[1:0] : ((req_func_id == 6'b110101) ? (2'b01) : (req_func_id[0] ? 2'b10 : 2'b00));
    end
    else begin
        assign vMul_vec1    = req_data1;
        assign vMul_opSel = req_func_id[1:0];
    end
endgenerate

generate
    if(ADD_SUB_ENABLE == 1) begin
        vAdd_min_max # (
            .REQ_DATA_WIDTH (REQ_DATA_WIDTH),
            .RESP_DATA_WIDTH(RESP_DATA_WIDTH),
            .SEW_WIDTH      (SEW_WIDTH),
            .OPSEL_WIDTH    (9),
            .MIN_MAX_ENABLE (MIN_MAX_ENABLE)
        ) vAdd_0 (
            .clk        (clk            ),
            .rst        (rst            ),
            .in_vec0    (vAdd_in0       ),
            .in_vec1    (vAdd_in1       ),
            .in_sew     (vAdd_sew       ),
            .in_valid   (vAdd_en        ),
            .in_opSel   ({vMinMax_en,vMinMax_opSel,vSigned_op,vAdd_opSel}),
            .in_addr    (req_addr       ),
            .out_vec    (vAdd_outVec    ),
            .out_valid  (vAdd_outValid  ),
            .out_addr   (vAdd_outAddr   )
        );
    end
    else begin
        assign vAdd_outVec = 'b0;
        assign vAdd_outValid = 'b0;
    end

    if(AND_OR_XOR_ENABLE == 1) begin
        vAndOrXor # (
            .REQ_DATA_WIDTH (REQ_DATA_WIDTH),
            .RESP_DATA_WIDTH(RESP_DATA_WIDTH),
            .OPSEL_WIDTH    (2)
        ) vAndOrXor_0   (
            .clk        (clk                ),
            .rst        (rst                ),
            .in_vec0    (req_data0          ),
            .in_vec1    (req_data1          ),
            .in_opSel   (vAndOrXor_opSel    ),
            .in_valid   (vAndOrXor_en       ),
            .in_addr    (req_addr           ),
            .out_vec    (vAndOrXor_outVec   ),
            .out_valid  (vAndOrXor_outValid ),
            .out_addr   (vAndOrXor_outAddr  )
        );
    end
    else begin
        assign vAndOrXor_outVec     = 'b0;
        assign vAndOrXor_outValid = 'b0;
        assign vAndOrXor_outAddr  = 'b0;
    end

    if(MULT_ENABLE == 1) begin
        vMul # (
            .REQ_DATA_WIDTH (REQ_DATA_WIDTH),
            .RESP_DATA_WIDTH(RESP_DATA_WIDTH),
            .SEW_WIDTH      (SEW_WIDTH),
            .MUL64_ENABLE   (MULT64_ENABLE),
            .OPSEL_WIDTH    (2)
        ) vMul_0 (
            .clk        (clk            ),
            .rst        (rst            ),
            .in_vec0    (vMul_in0       ),
            .in_vec1    (vMul_in1       ),
            .in_sew     (vMul_sew       ),
            .in_valid   (vMul_en        ),
            .in_opSel   (vMul_opSel     ),
            .in_widen   (vWiden_en      ),
            .in_addr    (req_addr       ),
            .out_vec    (vMul_outVec    ),
            .out_valid  (vMul_outValid  ),
            .out_addr   (vMul_outAddr   )
        );
    end
    else begin
        assign vMul_outVec      = 'b0;
        assign vMul_outValid = 'b0;
        assign vMul_outAddr  = 'b0;
    end

    if(SLIDE_ENABLE == 1) begin
        vSlide vSlide_0 (
            .clk        (clk            ),
            .rst        (rst            ),
            .in_vec0    (req_data0      ),
            .in_vec1    (vSlide_in1     ),
            .in_be      (req_be         ),
            .in_sew     (vSlide_insert ? req_sew : vSlide_sew),
            .in_valid   (vSlide_en      ),
            .in_start   (req_start      ),
            .in_end     (req_end        ),
            .in_opSel   (vSlide_opSel   ),
            .in_insert  (vSlide_insert  ),
            .in_addr    (req_addr       ),
            .out_be     (vSlide_outBe   ),
            .out_vec    (vSlide_outVec  ),
            .out_valid  (vSlide_outValid),
            .out_addr   (vSlide_outAddr)
        );
    end
    else begin
        assign vSlide_outBe     = 'b0;
        assign vSlide_outValid  = 'b0;
        assign vSlide_outVec    = 'b0;
        assign vSlide_outAddr   = 'b0;
    end

endgenerate


generate
    if(MASK_ENABLE) begin
        vMerge vMerge0(
            .clk        (clk            ),
            .rst        (rst            ),
            .in_mask    (req_be         ),
            .in_vec0    (req_data0      ),
            .in_vec1    (req_data1      ),
            .in_valid   (vMerge_en      ),
            .in_addr    (req_addr       ),
            .out_vec    (vMerge_outVec  ),
            .out_addr   (vMerge_outAddr ),
            .out_valid  (vMerge_outValid)
        );

        vMOP vMOP0 (
            .clk        (clk            ),
            .rst        (rst            ),
            .in_m0      (req_data0      ),
            .in_m1      (req_data1      ),
            .in_valid   (vMOP_en        ),
            .in_addr    (req_addr       ),
            .in_opSel   (vMOP_opSel     ),
            .out_vec    (vMOP_outVec    ),
            .out_valid  (vMOP_outValid  ),
            .out_addr   (vMOP_outAddr   )
        );

        vPopc vPopc0 (
            .clk        (clk            ),
            .rst        (rst            ),
            .in_m0      (req_be         ),
            .in_valid   (vPopc_en       ),
            .in_sew     (req_sew        ),
            .in_start   (req_start      ),
            .in_end     (req_end        ),
            .in_addr    (req_addr       ),
            .out_vec    (vPopc_outVec   ),
            .out_addr   (vPopc_outAddr  ),
            .out_valid  (vPopc_outValid )
        );

    end
    else begin
        assign vMerge_outVec    = 'b0;
        assign vMerge_outValid  = 'b0;
        assign vMerge_outAddr   = 'b0;

        assign vMOP_outVec      = 'b0;
        assign vMOP_outValid    = 'b0;
        assign vMOP_outAddr     = 'b0;

        assign vPopc_outVec     = 'b0;
        assign vPopc_outValid   = 'b0;
        assign vPopc_outAddr    = 'b0;
    end
endgenerate


generate
    if(REDUCTION_ENABLE) begin
        vRedAndOrXor vRedAndOrXor0 (
            .clk        (clk                    ),
            .rst        (rst                    ),
            .in_vec0    (req_data0              ),
            .in_vec1    (req_data1              ),
            .in_valid   (vRedAndOrXor_en        ),
            .in_start   (req_start              ),
            .in_end     (req_end                ),
            .in_opSel   (vRedAndOrXor_opSel     ),
            .in_sew     (req_sew                ),
            .in_addr    (req_addr               ),
            .out_vec    (vRedAndOrXor_outVec    ),
            .out_valid  (vRedAndOrXor_outValid  ),
            .out_addr   (vRedAndOrXor_outAddr   )
        );

        vRedSum_min_max vRedSum_min_max0 (
            .clk        (clk                        ),
            .rst        (rst                        ),
            .in_vec0    (req_data0                  ),
            .in_vec1    (req_data1                  ),
            .in_valid   (vRedSum_min_max_en         ),
            .in_start   (req_start                  ),
            .in_end     (req_end                    ),
            .in_opSel   (vRedSum_min_max_opSel      ),
            .in_sew     (req_sew                    ),
            .in_addr    (req_addr                   ),
            .out_vec    (vRedSum_min_max_outVec     ),
            .out_valid  (vRedSum_min_max_outValid   ),
            .out_addr   (vRedSum_min_max_outAddr    )
        );
    end
    else begin
        assign vRedAndOrXor_outVec      = 'b0;
        assign vRedAndOrXor_outValid    = 'b0;
        assign vRedAndOrXor_outAddr     = 'b0;

        assign vRedSum_min_max_outVec   = 'b0;
        assign vRedSum_min_max_outValid = 'b0;
        assign vRedSum_min_max_outAddr  = 'b0;
    end
endgenerate

generate
    if(VEC_MOVE_ENABLE) begin
        vMove vMove0 (
            .clk      (clk              ),
            .rst      (rst              ),
            .in_vec0  (req_data0        ),
            .in_valid (vMove_en         ),
            .in_addr  (req_addr         ),
            .out_vec  (vMove_outVec     ),
            .out_valid(vMove_outValid   ),
            .out_addr (vMove_outAddr    )
        );
    end
    else begin
        assign vMove_outVec     = 'b0;
        assign vMove_outValid   = 'b0;
        assign vMove_outAddr    = 'b0;
    end
endgenerate

always @(posedge clk) begin
    if(rst) begin
        resp_data       <= 'b0;
        resp_valid      <= 'b0;

        s0_func_id      <= 'b0;
        s1_func_id      <= 'b0;
        s2_func_id      <= 'b0;
        s3_func_id      <= 'b0;
        s4_func_id      <= 'b0;

        s0_be           <= 'b0;
        s1_be           <= 'b0;
        s2_be           <= 'b0;
        s3_be           <= 'b0;
        s4_be           <= 'b0;
        s5_be           <= 'b0;

        s0_vl           <= 'b0;
        s1_vl           <= 'b0;
        s2_vl           <= 'b0;
        s3_vl           <= 'b0;
        s4_vl           <= 'b0;
        s5_vl           <= 'b0;
        turn            <= 'b0;
    end
    else begin
        s0_func_id      <= req_func_id;
        s1_func_id      <= s0_func_id;
        s2_func_id      <= s1_func_id;
        s3_func_id      <= s2_func_id;
        s4_func_id      <= s3_func_id;

        s0_vl           <= req_vl;
        s1_vl           <= s0_vl;
        s2_vl           <= s1_vl;
        s3_vl           <= s2_vl;
        s4_vl           <= s3_vl;
        s5_vl           <= s4_vl;
        req_vl_out      <= s5_vl;

        s0_be           <= req_be & (vWiden_en ? vWiden_be : {8{~(vSlide_en | vNarrow_en)}});
        s1_be           <= s0_be;
        s2_be           <= s1_be;
        s3_be           <= s2_be;
        s4_be           <= s3_be;
        s5_be           <= s4_be;

        req_be_out      <= vSlide_outBe     | s5_be         | vNarrow_be;

        resp_valid      <= vMove_outValid   | vAdd_outValid | vAndOrXor_outValid| vMul_outValid | vSlide_outValid | vNarrow_outValid
                            | vMerge_outValid   | vMOP_outValid | vPopc_outValid| vRedAndOrXor_outValid | vRedSum_min_max_outValid;

        resp_data       <= vMove_outVec     | vAdd_outVec   | vAndOrXor_outVec  | vMul_outVec   | vSlide_outVec | vNarrow_outVec
                            | vMerge_outVec     | vMOP_outVec   | vPopc_outVec  | vRedAndOrXor_outVec   | vRedSum_min_max_outVec;

        req_addr_out    <= vMove_outAddr    | vAdd_outAddr  | vAndOrXor_outAddr | vMul_outAddr  | vSlide_outAddr | vNarrow_outAddr
                            | vMerge_outAddr    | vMOP_outAddr  | vPopc_outAddr | vRedAndOrXor_outAddr  | vRedSum_min_max_outAddr;

        if(req_end)
            turn        <= 'b0;
        else if (vWiden_en | vNarrow_en)
            turn        <= ~turn;
        else
            turn        <= turn;

    end
end
endmodule