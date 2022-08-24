`include "vAdd_min_max.v"
`include "vAndOrXor.v"
`include "vMerge.v"
`include "vMOP.v"
`include "vMove.v"
`include "vMul.v"
`include "vNarrow.v"
`include "vPopc.v"
`include "vFirst.sv"
`include "vRedAndOrXor.v"
`include "vRedSum_min_max.v"
`include "vSlide.v"
`include "vWiden.v"
`include "vMinMaxSelector.v"
`include "vAdd_unit_block.v"
`include "vID.sv"
`include "fxp_round.sv"

// TODO optional 64-bit
// TODO separate masking instructions - test area
// TODO fix separation of mul/shift

module vALU #(
    parameter REQ_FUNC_ID_WIDTH = 6 ,
    parameter REQ_DATA_WIDTH    = 64,
    parameter RESP_DATA_WIDTH   = 64,
    parameter SEW_WIDTH         = 2 ,
    parameter REQ_ADDR_WIDTH    = 32,
    parameter REQ_VL_WIDTH      = 8 ,
    parameter REQ_BYTE_EN_WIDTH = REQ_DATA_WIDTH>>3,
    parameter AND_OR_XOR_ENABLE = 1 ,
    parameter ADD_SUB_ENABLE    = 1 ,
    parameter MIN_MAX_ENABLE    = 1 ,
    parameter VEC_MOVE_ENABLE   = 1 ,
    parameter WIDEN_ENABLE      = 1 ,
    parameter NARROW_ENABLE     = 1 ,
    parameter REDUCTION_ENABLE  = 1 ,
    parameter MULT_ENABLE       = 1 ,
    parameter MULT64_ENABLE     = 1 ,
    parameter SHIFT_ENABLE      = 1 ,
    parameter SLIDE_ENABLE      = 1 ,
    parameter SLIDE_N_ENABLE    = 1 ,
    parameter MASK_ENABLE       = 1 ,
    parameter FXP_ENABLE        = 1 ,
    parameter SHIFT64_ENABLE    = 1
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
    input      [                 10:0] req_vr_idx  , // we include this for insns where we need to know index in register groups
    input                              req_start   ,
    input                              req_end     ,
    input                              req_mask    ,
    input      [                  7:0] req_off     ,
    input                              req_whole_reg,
    input      [                  1:0] req_vxrm    ,
    output reg                         resp_valid  ,
    output reg                         resp_start  ,
    output reg                         resp_end    ,
    output reg [  RESP_DATA_WIDTH-1:0] resp_data   ,
    output                             req_ready   ,
    output reg [   REQ_ADDR_WIDTH-1:0] req_addr_out,
    output reg [                  7:0] resp_off    ,
    output reg [     REQ_VL_WIDTH-1:0] req_vl_out  ,
    output reg [REQ_BYTE_EN_WIDTH-1:0] req_be_out  ,
    output reg                         resp_mask_out,
    output reg                         resp_sca_out,
    output reg                         resp_whole_reg
);

reg  [REQ_BYTE_EN_WIDTH-1:0]    s0_be, s1_be, s2_be, s3_be, s4_be, s5_be;
reg  [                  1:0]    s0_vxrm, s1_vxrm, s2_vxrm, s3_vxrm, s4_vxrm, s5_vxrm;
reg                             s0_start, s1_start, s2_start, s3_start, s4_start, s5_start;
reg                             s0_end, s1_end, s2_end, s3_end, s4_end, s5_end;
reg  [     REQ_VL_WIDTH-1:0]    s0_vl, s1_vl, s2_vl, s3_vl, s4_vl, s5_vl;

reg  [                  7:0]    s0_off, s1_off, s2_off, s3_off, s4_off, s5_off; // TODO pipe through modules
reg                             turn;

wire [   REQ_DATA_WIDTH-1:0]    vWiden_in0, vWiden_in1;
wire [   REQ_DATA_WIDTH-1:0]    vAdd_in0, vAdd_in1, vMul_in0, vMul_in1, vSlide_in1;
wire [   REQ_DATA_WIDTH-1:0]    vAvAdd_outVec, vScShift_outVec;
wire [                  1:0]    vAndOrXor_opSel, vMul_opSel, vAdd_opSel;
wire [   REQ_DATA_WIDTH-1:0]    vMul_vec1       ;
wire [   REQ_DATA_WIDTH-1:0]    vMul_vec0       ;
wire [   REQ_DATA_WIDTH-1:0]    vShift_mult_sew [0:3];
// wire [   REQ_DATA_WIDTH-1:0]    vShift_mult;
wire [   REQ_DATA_WIDTH-1:0]    vShift_upper    ;
wire [   REQ_DATA_WIDTH-1:0]    vShift_vd10     ;
wire [                  6:0]    vShift_inShift  ;
wire                            vShiftR64       ;
wire                            vShift_orTop    ;
// wire [                  6:0]    vShift_cmpl     ;
wire [   REQ_DATA_WIDTH-1:0]    vShift_cmpl_sew [0:3];
wire [   REQ_DATA_WIDTH-1:0]    vShift_cmpl;
wire [                  1:0]    vSlide_sew, vWiden_sew, vAdd_sew, vMul_sew;
wire [REQ_BYTE_EN_WIDTH-1:0]    vSlide_outBe, vWiden_be, vNarrow_be, vMCmp_outBe;
wire                            vMinMax_opSel, vRightShift_opSel, vSlide_opSel;
wire                            vAdd_outMask;
wire                            vSigned_op     ;
wire                            vSlide_insert  ; //TODO: assign something

wire [                 11:0]    vStartIdx;

wire [  RESP_DATA_WIDTH-1:0]    vMerge_outVec, vMOP_outVec, vPopc_outVec, vRedAndOrXor_outVec, vRedSum_min_max_outVec, vMove_outVec, vID_outVec, vFirst_outVec,
                                vAdd_outVec, vAndOrXor_outVec, vMul_outVec, vSlide_outVec, vNarrow_outVec, fxp_out;
wire                            vMerge_outValid, vMOP_outValid, vPopc_outValid, vRedAndOrXor_outValid, vRedSum_min_max_outValid, vMove_outValid, 
                                vID_outValid, vFirst_outValid, vAdd_outValid, vAndOrXor_outValid, vMul_outValid, vSlide_outValid, vNarrow_outValid;
wire                            vMove_outWReg;
wire [                  9:0]    vRedAndOrXor_opSel, vRedSum_min_max_opSel;
wire [                  2:0]    vMask_opSel;
wire                            vMove_en, vMerge_en, vMOP_en, vPopc_en, vRedAndOrXor_en, vRedSum_min_max_en,  vMCmp_en, vFirst_en, vAdd_en, vMinMax_en,
                                vAndOrXor_en, vMul_en, vSlide_en, vID_en, vNarrow_en, vWiden_en, vAAdd_en, vSShift_en;

wire [   REQ_ADDR_WIDTH-1:0]    vMove_outAddr, vAdd_outAddr, vAndOrXor_outAddr, vMul_outAddr, vSlide_outAddr, vNarrow_outAddr, vMerge_outAddr,
                                vMOP_outAddr, vPopc_outAddr, vRedAndOrXor_outAddr, vRedSum_min_max_outAddr, vID_outAddr, vFirst_outAddr;

wire [REQ_BYTE_EN_WIDTH-1:0]    vAAdd_vd, vAAdd_vd1, vMul_vd, vMul_vd1, vMul_vd10;

wire                            vMove_outSca;

// TODO: Update enable signals for FP instr later
assign vAdd_en              = req_valid & ((req_func_id[5:3] == 3'b000) | (req_func_id[5:2] == 4'b1100) | ((req_func_id[5:2] == 4'b0010) & (req_op_mnr[1:0] == 2'h2)) | ((req_func_id[5:3] == 3'b011) & (req_op_mnr[1]^req_op_mnr[0] == 1'b0)));
assign vAAdd_en             = req_valid & (req_func_id[5:2] == 4'b0010) & (req_op_mnr[1:0] == 2'h2); // averaging add - reuse add unit
assign vAndOrXor_en         = req_valid & (req_func_id[5:2] == 4'b0010) & (req_op_mnr[1]^req_op_mnr[0] == 1'b0);
assign vMinMax_en           = req_valid & (req_func_id[5:2] == 4'b0001);
assign vMul_en              = req_valid & ((req_func_id[5:2] == 4'b1001) | (req_func_id[5:2] == 4'b1010) | (req_func_id == 6'b110101) | (req_func_id[5:2] == 4'b1110));
assign vSlide_en            = req_valid & (req_func_id[5:1] == 5'b00111);
assign vMove_en             = req_valid & ((req_func_id == 6'b010111) & req_mask) | (req_func_id == 6'b100111 & req_op_mnr == 3'h3);

assign vNarrow_en           = req_valid & (req_func_id == 6'b101100);
assign vMerge_en            = req_valid & (req_func_id == 6'b010111) & ~req_mask;
assign vMOP_en              = req_valid & (req_func_id[5:3] == 3'b011) & (req_op_mnr === 3'h2);
assign vMCmp_en             = req_valid & (req_func_id[5:3] == 3'b011) & (req_op_mnr[1]^req_op_mnr[0] == 1'b0);
assign vPopc_en             = req_valid & (req_func_id == 'h10) & (req_data0 == 'h10); // Popc uses VWXUNARY0
assign vFirst_en            = req_valid & (req_func_id == 'h10) & (req_data0 == 'h11); // First uses VWXUNARY0
assign vID_en               = req_valid & (req_func_id == 'h14) & (req_data0 == 'h11); // vid uses VMUNARY0
assign vRedAndOrXor_en      = req_valid & (|req_func_id[1:0] & req_func_id[5:2] == 4'b0000) & (req_op_mnr == 3'h2);
assign vRedSum_min_max_en   = req_valid & (req_func_id == 6'b0 | req_func_id[5:2] == 4'b0001) & (req_op_mnr == 3'h2);

// FIXME
assign vMoveXS_en           = req_valid & (req_func_id == 'h10) & (req_data0 == 'h0) & (req_op_mnr == 3'h2);
assign vMoveSX_en           = req_valid & (req_func_id == 'h10) & (req_data1 == 'h0) & (req_op_mnr == 3'h6);

assign vSShift_en           = req_valid & (req_func_id[5:1] == 5'b10101) & (req_op_mnr[1]^req_op_mnr[0] == 1'b0);
assign vSMul_en             = req_valid & (req_func_id[5:1] == 5'b10011) & (req_op_mnr[1:0] == 2'h0);

generate
    if (SLIDE_N_ENABLE) begin
        assign vSlide_sew           = req_data0[3] ? (req_sew + 2'b11) : (req_data0[2] ? (req_sew + 2'b10) : (req_data0[1] ? (req_sew + 2'b01) : (req_sew)));
    end else begin
        assign vSlide_sew           = req_sew;
    end
endgenerate

assign vSlide_insert        = 0;
assign req_ready            = 1'b1; //TODO: control

assign vAdd_sew             = vWiden_en ? vWiden_sew : req_sew;
assign vMul_sew             = vWiden_en ? vWiden_sew : req_sew;

assign vAdd_in0             = vWiden_en ? vWiden_in0 : req_data0;
assign vAdd_in1             = vWiden_en ? vWiden_in1 : req_data1;
assign vMul_in0             = vWiden_en ? vWiden_in0 : vMul_vec0;
assign vMul_in1             = vWiden_en ? vWiden_in1 : vMul_vec1;

assign vSlide_in1           = vSlide_insert ? req_data0 : 'b0;

assign vRightShift_opSel    = req_func_id[0];
assign vMinMax_opSel        = req_func_id[1];
assign vSigned_op           = req_func_id[0];
assign vAndOrXor_opSel      = req_func_id[1:0];
assign vAdd_opSel           = (req_func_id[2] | vMCmp_en) ? 2'b10 : req_func_id[1:0];
assign vSlide_opSel         = req_func_id[0];
assign vMask_opSel          = req_func_id[2:0];
assign vRedAndOrXor_opSel   = req_func_id[1:0];
assign vRedSum_min_max_opSel= req_func_id[0];

assign vStartIdx            = req_vr_idx << ('h3 - req_sew);

vID #(
    .REQ_BYTE_EN_WIDTH(REQ_BYTE_EN_WIDTH),
    .REQ_ADDR_WIDTH(REQ_ADDR_WIDTH),
    .RESP_DATA_WIDTH(RESP_DATA_WIDTH))
vID_0 (
    .clk            (clk            ),
    .rst            (rst            ),
    .in_sew         (req_sew        ),
    .in_valid       (vID_en         ),
    .in_addr        (req_addr       ),
    .in_start_idx   (vStartIdx      ),
    .out_vec        (vID_outVec     ),
    .out_valid      (vID_outValid   ),
    .out_addr       (vID_outAddr    )
);

generate
    if(WIDEN_ENABLE) begin : widen
        assign vWiden_en    = (&req_func_id[5:4] & ~req_func_id[2]);

        vWiden #(
            .REQ_BYTE_EN_WIDTH(REQ_BYTE_EN_WIDTH),
            .RESP_DATA_WIDTH(RESP_DATA_WIDTH)
            ) vWiden_0 (
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
    if(NARROW_ENABLE) begin : narrow
        vNarrow #(
            .REQ_BYTE_EN_WIDTH(REQ_BYTE_EN_WIDTH),
            .REQ_ADDR_WIDTH(REQ_ADDR_WIDTH),
            .RESP_DATA_WIDTH(RESP_DATA_WIDTH)
            ) vNarrow_0 (
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

genvar i,j;

generate
    if(SHIFT_ENABLE) begin : shift
        if (SHIFT64_ENABLE) begin : shift64
            assign vShiftR64 = ((req_func_id[5:2] == 4'b1010) & (req_op_mnr[1]^req_op_mnr[0] == 'b0)) & (req_sew[1] & req_sew[0]);

            for (i = 0; i < (REQ_DATA_WIDTH >> 6); i = i + 1) begin
                assign vShift_upper[i*64 +: 64] = vShift_orTop ? req_data1 : {32'b0,req_data1[(i*64 + 32) +: 32]}; // upper 32b

                if (FXP_ENABLE) begin
                    assign vShift_vd10[i*64 +: 64] = vShift_orTop ? 0 : (|req_data1[(i*64) +: 32]); // lower 32b
                end else begin
                    assign vShift_vd10 = 'h0;
                end
            end

            assign vShift_orTop = (req_data0 < 32);

            assign vMul_vec0    = vShiftR64 ? vShift_upper : req_data1;

            assign vShift_inShift = vShiftR64 ? req_data0[6:0] : 'h0;
        end else begin
            assign vShiftR64    = 'b0;
            assign vShift_orTop = 'b0;
            assign vShift_vd10  = 'b0;

            assign vMul_vec0    = req_data1;
            assign vShift_inShift = 'h0;
        end
        // assign vShift_cmpl = req_sew[1] ? (req_sew[0] ? 7'd64 : 7'd32) : (req_sew[0] ? 7'd16 : 7'd8); // fixme - doesn't work for vv
        // assign vShift_mult = (req_func_id[5:2] == 4'b1010) & ~(req_sew[1] & req_sew[1]) ? 2**(vShift_cmpl-req_data0[6:0]) : 2**(req_data0[6:0]);

        for (j = 0; j < 4; j = j + 1) begin
            for (i = 0; i < (REQ_DATA_WIDTH >> (j+3)); i = i + 1) begin
                if (j < 3) begin
                    assign vShift_cmpl_sew[j][(i << (j+3)) +: (1 << (j+3))] = (req_func_id[5:2] == 4'b1010)? (1'b1 << j + 3) - req_data0[(i << (j+3)) +: (1 << (j+3))] : req_data0[(i << (j+3)) +: (1 << (j+3))];
                    // FIXME add "or top"
                end else begin
                    assign vShift_cmpl_sew[j][i*64 +: 64] = (req_func_id[5:2] == 4'b1010)? (req_data0[i*64 +: 64] < 32 ? 32 - req_data0[i*64 +: 64] : 64 - req_data0[i*64 +: 64]) : req_data0[i*64 +: 64];
                end
                assign vShift_mult_sew[j][(i << (j+3)) +: (1 << (j+3))] = 2**(vShift_cmpl_sew[j][(i << (j+3)) +: (1 << (j+3))]);
            end
        end

        assign vMul_vec1   = (req_func_id[5:2] == 4'b1001) ? req_data0 : vShift_mult_sew[req_sew];

        assign vMul_opSel  = (req_func_id[5:2] == 4'b1001) ? req_func_id[1:0] : ((req_func_id == 6'b110101) ? (2'b01) : {req_func_id[0],0});
    end
    else begin
        assign vMul_vec1    = req_data0;
        assign vMul_vec0    = req_data1;
        assign vMul_opSel   = req_func_id[1:0];
        assign vShift_orTop = 'b0;
        assign vShift_vd10  = 'b0;
    end
endgenerate

generate
    if(ADD_SUB_ENABLE | MASK_ENABLE) begin : add_sub
        vAdd_min_max # (
            .REQ_DATA_WIDTH (REQ_DATA_WIDTH),
            .RESP_DATA_WIDTH(RESP_DATA_WIDTH),
            .REQ_ADDR_WIDTH(REQ_ADDR_WIDTH),
            .SEW_WIDTH      (SEW_WIDTH),
            .OPSEL_WIDTH    (9),
            .MIN_MAX_ENABLE (MIN_MAX_ENABLE),
            .MASK_ENABLE    (MASK_ENABLE)
        ) vAdd_0 (
            .clk        (clk            ),
            .rst        (rst            ),
            .in_vec0    (vAdd_in0       ),
            .in_vec1    (vAdd_in1       ),
            .in_sew     (vAdd_sew       ),
            .in_valid   (vAdd_en        ),
            .in_opSel   ({vMCmp_en,vMask_opSel,vMinMax_en,vMinMax_opSel,vSigned_op,vAdd_opSel}),
            .in_addr    (req_addr       ),
            .in_start_idx(vStartIdx     ),
            .in_req_start(req_start     ),
            .in_req_end  (req_end       ),
            .in_be      (req_be         ),
            .in_avg     (vAAdd_en       ),
            .out_vec    (vAdd_outVec    ),
            .out_valid  (vAdd_outValid  ),
            .out_addr   (vAdd_outAddr   ),
            .out_be     (vMCmp_outBe    ),
            .out_mask   (vAdd_outMask   ),
            .out_vd     (vAAdd_vd       ),
            .out_vd1    (vAAdd_vd1      )
        );
    end
    else begin
        assign vAdd_outVec      = 'b0;
        assign vAdd_outValid    = 'b0;

        assign vAAdd_vd         = 'b0;
        assign vAAdd_vd1        = 'b0;
    end

    if(AND_OR_XOR_ENABLE) begin : and_or_xor
        vAndOrXor # (
            .REQ_DATA_WIDTH (REQ_DATA_WIDTH),
            .RESP_DATA_WIDTH(RESP_DATA_WIDTH),
            .REQ_ADDR_WIDTH(REQ_ADDR_WIDTH),
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
        assign vAndOrXor_outValid   = 'b0;
        assign vAndOrXor_outAddr    = 'b0;
    end

    if(MULT_ENABLE) begin : mult
        vMul # (
            .REQ_DATA_WIDTH (REQ_DATA_WIDTH),
            .RESP_DATA_WIDTH(RESP_DATA_WIDTH),
            .REQ_ADDR_WIDTH(REQ_ADDR_WIDTH),
            .SEW_WIDTH      (SEW_WIDTH),
            .MUL64_ENABLE   (MULT64_ENABLE),
            .FXP_ENABLE     (FXP_ENABLE),
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
            .in_fxp_s   (vSShift_en     ),
            .in_fxp_mul (vSMul_en       ),
            .in_sr_64   (vShiftR64      ), // FIXME
            .in_or_top  (vShift_orTop   ),
            .in_vd10    (vShift_vd10    ),
            .in_shift   (vShift_inShift ),
            .out_vec    (vMul_outVec    ),
            .out_valid  (vMul_outValid  ),
            .out_addr   (vMul_outAddr   ),
            .out_vd     (vMul_vd        ),
            .out_vd1    (vMul_vd1       ),
            .out_vd10   (vMul_vd10      )
        );
    end
    else begin
        assign vMul_outVec      = 'b0;
        assign vMul_outValid    = 'b0;
        assign vMul_outAddr     = 'b0;
    end

    if(SLIDE_ENABLE) begin : slide
        vSlide #(
            .REQ_DATA_WIDTH (REQ_DATA_WIDTH),
            .RESP_DATA_WIDTH(RESP_DATA_WIDTH),
            .REQ_ADDR_WIDTH(REQ_ADDR_WIDTH)
            ) vSlide_0 (
            .clk        (clk            ),
            .rst        (rst            ),
            .in_vec0    (req_data1      ),
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
    if(MASK_ENABLE) begin : mask
        vMerge # (
            .REQ_DATA_WIDTH (REQ_DATA_WIDTH),
            .RESP_DATA_WIDTH(RESP_DATA_WIDTH),
            .REQ_ADDR_WIDTH(REQ_ADDR_WIDTH)
            )vMerge0(
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

        vMOP #(
            .REQ_DATA_WIDTH (REQ_DATA_WIDTH),
            .RESP_DATA_WIDTH(RESP_DATA_WIDTH),
            .REQ_ADDR_WIDTH(REQ_ADDR_WIDTH)
            ) vMOP0 (
            .clk        (clk            ),
            .rst        (rst            ),
            .in_m0      (req_data0      ),
            .in_m1      (req_data1      ),
            .in_valid   (vMOP_en        ),
            .in_addr    (req_addr       ),
            .in_opSel   (vMask_opSel    ),
            .out_vec    (vMOP_outVec    ),
            .out_valid  (vMOP_outValid  ),
            .out_addr   (vMOP_outAddr   )
        );

        vPopc #(
            .REQ_DATA_WIDTH (REQ_DATA_WIDTH),
            .RESP_DATA_WIDTH(RESP_DATA_WIDTH),
            .REQ_ADDR_WIDTH(REQ_ADDR_WIDTH)
            ) vPopc0 (
            .clk        (clk            ),
            .rst        (rst            ),
            .in_m0      (req_data1      ),
            .in_valid   (vPopc_en       ),
            .in_end     (req_end        ),
            .in_addr    (req_addr       ),
            .out_vec    (vPopc_outVec   ),
            .out_addr   (vPopc_outAddr  ),
            .out_valid  (vPopc_outValid )
        );

        vFirst #(
            .REQ_DATA_WIDTH (REQ_DATA_WIDTH),
            .RESP_DATA_WIDTH(RESP_DATA_WIDTH),
            .REQ_ADDR_WIDTH(REQ_ADDR_WIDTH)
            ) vFirst0 (
            .clk        (clk            ),
            .rst        (rst            ),
            .in_m0      (req_data1      ),
            .in_valid   (vFirst_en      ),
            .in_end     (req_end        ),
            .in_addr    (req_addr       ),
            .in_start_idx(vStartIdx     ),
            .out_vec    (vFirst_outVec  ),
            .out_addr   (vFirst_outAddr ),
            .out_valid  (vFirst_outValid)
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

        assign vFirst_outVec    = 'b0;
        assign vFirst_outValid  = 'b0;
        assign vFirst_outAddr   = 'b0;
    end
endgenerate


generate
    if(REDUCTION_ENABLE) begin : red
        vRedAndOrXor #(
            .REQ_DATA_WIDTH (REQ_DATA_WIDTH),
            .RESP_DATA_WIDTH(RESP_DATA_WIDTH),
            .REQ_ADDR_WIDTH(REQ_ADDR_WIDTH)
            ) vRedAndOrXor0 (
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

        vRedSum_min_max #(
            .REQ_DATA_WIDTH (REQ_DATA_WIDTH),
            .RESP_DATA_WIDTH(RESP_DATA_WIDTH),
            .REQ_ADDR_WIDTH(REQ_ADDR_WIDTH)
            ) vRedSum_min_max0 (
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
    if(VEC_MOVE_ENABLE) begin : move 
        vMove #(
            .REQ_DATA_WIDTH (REQ_DATA_WIDTH),
            .RESP_DATA_WIDTH(RESP_DATA_WIDTH),
            .REQ_ADDR_WIDTH(REQ_ADDR_WIDTH)
            ) vMove0 (
            .clk      (clk              ),
            .rst      (rst              ),
            .in_vec0  ((vMoveXS_en | req_whole_reg) ? req_data1 : req_data0),
            .in_valid (vMove_en | vMoveSX_en | vMoveXS_en),
            .in_addr  (req_addr         ),
            .in_w_reg (req_whole_reg    ),
            .in_sca   (vMoveXS_en       ),
            .in_be    (req_be           ),
            .out_vec  (vMove_outVec     ),
            .out_valid(vMove_outValid   ),
            .out_addr (vMove_outAddr    ),
            .out_w_reg(vMove_outWReg    ),
            .out_sca  (vMove_outSca     )
        );
    end
    else begin
        assign vMove_outVec     = 'b0;
        assign vMove_outValid   = 'b0;
        assign vMove_outAddr    = 'b0;
        assign vMove_outWReg    = 'b0;
    end
endgenerate

generate
    if (FXP_ENABLE) begin : fxp_round
        fxp_round #(.DATA_WIDTH(REQ_DATA_WIDTH)) fxp (.clk(clk), .rst (rst),
            .vxrm (s5_vxrm), .in_valid(vAdd_outValid | vMul_outValid), .vec_in(vAdd_outVec | vMul_outVec),
            .v_d(vAAdd_vd | vMul_vd), .v_d1(vAAdd_vd1 | vMul_vd1), .v_d10(vAAdd_vd1 | vMul_vd10),
            .vec_out(fxp_out));
    end else begin
        assign fxp_out = vAdd_outVec | vMul_outVec;
    end
endgenerate

always @(posedge clk) begin
    if(rst) begin
        resp_data       <= 'b0;
        resp_valid      <= 'b0;

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
        s0_vl           <= req_vl;
        s1_vl           <= s0_vl;
        s2_vl           <= s1_vl;
        s3_vl           <= s2_vl;
        s4_vl           <= s3_vl;
        s5_vl           <= s4_vl;
        req_vl_out      <= s5_vl;

        s0_vxrm         <= req_vxrm;
        s1_vxrm         <= s0_vxrm;
        s2_vxrm         <= s1_vxrm;
        s3_vxrm         <= s2_vxrm;
        s4_vxrm         <= s3_vxrm;
        s5_vxrm         <= s4_vxrm;

        // TODO pipe these through modules instead, so timing of outputs is guaranteed
        s0_be           <= vWiden_en ? vWiden_be : ((vSlide_en | vNarrow_en | vMCmp_en) ? 'h0 : req_be);
        s1_be           <= s0_be;
        s2_be           <= s1_be;
        s3_be           <= s2_be;
        s4_be           <= s3_be;
        s5_be           <= s4_be;

        s0_start        <= req_start & req_valid;
        s1_start        <= s0_start;
        s2_start        <= s1_start;
        s3_start        <= s2_start;
        s4_start        <= s3_start;
        s5_start        <= s4_start;
        resp_start      <= s5_start;

        s0_end          <= req_end & req_valid;
        s1_end          <= s0_end;
        s2_end          <= s1_end;
        s3_end          <= s2_end;
        s4_end          <= s3_end;
        s5_end          <= s4_end;
        resp_end        <= s5_end;

        s0_off          <= req_valid ? req_off : 'h0;
        s1_off          <= s0_off;
        s2_off          <= s1_off;
        s3_off          <= s2_off;
        s4_off          <= s3_off;
        s5_off          <= s4_off;
        resp_off        <= s5_off;

        req_be_out      <=  vSlide_outBe        | s5_be         | vNarrow_be        | vMCmp_outBe;

        resp_valid      <= vMove_outValid       | vAdd_outValid | vAndOrXor_outValid| vMul_outValid         | vSlide_outValid           | vNarrow_outValid
                            | vMerge_outValid   | vMOP_outValid | vPopc_outValid    | vRedAndOrXor_outValid | vRedSum_min_max_outValid
                            | vID_outValid      | vFirst_outValid;

        resp_data       <= vMove_outVec         | fxp_out       | vAndOrXor_outVec  | vSlide_outVec         | vNarrow_outVec
                            | vMerge_outVec     | vMOP_outVec   | vPopc_outVec      | vRedAndOrXor_outVec   | vRedSum_min_max_outVec
                            | vID_outVec        | vFirst_outVec;

        req_addr_out    <= vMove_outAddr        | vAdd_outAddr  | vAndOrXor_outAddr | vMul_outAddr          | vSlide_outAddr            | vNarrow_outAddr
                            | vMerge_outAddr    | vMOP_outAddr  | vPopc_outAddr     | vRedAndOrXor_outAddr  | vRedSum_min_max_outAddr
                            | vID_outAddr       | vFirst_outAddr;

        resp_mask_out   <= vMOP_outValid        | (vAdd_outValid & vAdd_outMask);

        resp_sca_out    <= vFirst_outValid      | vPopc_outValid | vMove_outSca;

        resp_whole_reg  <= vMove_outWReg;

        if(req_end)
            turn        <= 'b0;
        else if (vWiden_en | vNarrow_en)
            turn        <= ~turn;
        else
            turn        <= turn;

    end
end
endmodule