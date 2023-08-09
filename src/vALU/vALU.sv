module vALU 
  import opcodes::*;
  #(
    parameter REQ_FUNC_ID_WIDTH = 6 ,
    parameter REQ_DATA_WIDTH    = 64,
    parameter RESP_DATA_WIDTH   = 64,
    parameter SEW_WIDTH         = 2 ,
    parameter REQ_ADDR_WIDTH    = 32,
    parameter REQ_VL_WIDTH      = 12 ,
    parameter REQ_BYTE_EN_WIDTH = REQ_DATA_WIDTH>>3,
    parameter AND_OR_XOR_ENABLE = 1 ,
    parameter ADD_SUB_ENABLE    = 1 ,
    parameter MIN_MAX_ENABLE    = 1 ,
    parameter VEC_MOVE_ENABLE   = 1 ,
    parameter WHOLE_REG_ENABLE  = 1 ,
    parameter WIDEN_ADD_ENABLE  = 1 ,
    parameter REDUCTION_ENABLE  = 1 ,
    parameter MULT_ENABLE       = 1 ,
    parameter SHIFT_ENABLE      = 1 ,
    parameter MULH_SR_ENABLE    = 1 ,
    parameter MULH_SR_32_ENABLE = 1 ,
    parameter NARROW_ENABLE     = 1 ,
    parameter WIDEN_MUL_ENABLE  = 1 ,
    parameter SLIDE_ENABLE      = 1 ,
    parameter SLIDE_N_ENABLE    = 1 ,
    parameter MULT64_ENABLE     = 1 ,
    parameter SHIFT64_ENABLE    = 1 ,
    parameter MASK_ENABLE       = 1 ,
    parameter MASK_ENABLE_EXT   = 1 ,
    parameter FXP_ENABLE        = 1 ,
    parameter ENABLE_64_BIT     = 1 ,
    parameter EN_128_MUL        = 0
  ) 
  (
    input  logic clk ,
    input  logic rst ,
    input  logic req_valid ,
    input  logic [32-1:0] req_insn , // [NEW]
    input  logic [2:0] req_op_mnr ,
    input  logic [REQ_FUNC_ID_WIDTH-1:0] req_func_id ,
    input  logic [SEW_WIDTH-1:0] req_sew ,
    input  logic [REQ_DATA_WIDTH-1:0] req_data0 ,
    input  logic [REQ_DATA_WIDTH-1:0] req_data1 ,
    input  logic [REQ_ADDR_WIDTH-1:0] req_addr ,
    input  logic [REQ_BYTE_EN_WIDTH-1:0] req_be ,
    input  logic [REQ_VL_WIDTH-1:0] req_vl      ,
    input  logic [11-1:0] req_vr_idx , // we include this for insns where we need to know index in register groups
    input  logic req_start ,
    input  logic req_end ,
    input  logic req_mask ,
    input  logic [7:0] req_off ,
    input  logic [1:0] req_vxrm ,
    input  logic req_slide1 ,
    output logic resp_valid ,
    output logic resp_start ,
    output logic resp_end ,
    output logic [RESP_DATA_WIDTH-1:0] resp_data ,
    output logic [1:0] resp_sew ,
    output logic req_ready ,
    output logic [REQ_ADDR_WIDTH-1:0] resp_addr,
    output logic [7:0] resp_off ,
    output logic [REQ_VL_WIDTH-1:0] req_vl_out  ,
    output logic [REQ_BYTE_EN_WIDTH-1:0] resp_be ,
    output logic resp_mask_out,
    output logic resp_sca_out,
    output logic resp_whole_reg,
    output logic resp_narrow
    );

    logic [REQ_BYTE_EN_WIDTH-1:0] s0_be, s1_be, s2_be, s3_be, s4_be, s5_be;
    logic [1:0] s0_vxrm, s1_vxrm, s2_vxrm, s3_vxrm, s4_vxrm, s5_vxrm;
    logic s0_start, s1_start, s2_start, s3_start, s4_start, s5_start;
    logic s0_end, s1_end, s2_end, s3_end, s4_end, s5_end;

    logic [1:0] s0_sew, s1_sew, s2_sew, s3_sew, s4_sew, s5_sew;

    logic [7:0] s0_off, s1_off, s2_off, s3_off, s4_off, s5_off; // TODO pipe through modules
    logic turn;

    logic [REQ_ADDR_WIDTH-1:0] s0_out_addr, s1_out_addr, s2_out_addr, s3_out_addr, s4_out_addr, s5_out_addr;

    logic [REQ_DATA_WIDTH-1:0] vWiden_in0, vWiden_in1;
    logic [REQ_DATA_WIDTH-1:0] vAdd_in0, vAdd_in1, vMul_in0, vMul_in1, vSlide_in1, vAndOrXor_in0, vAndOrXor_in1;
    logic [REQ_DATA_WIDTH-1:0] vAvAdd_outVec, vScShift_outVec;
    logic [1:0] vAndOrXor_opSel, vMul_opSel, vAdd_opSel;
    logic [REQ_DATA_WIDTH-1:0] vMul_vec1 ;
    logic [REQ_DATA_WIDTH-1:0] vMul_vec0 ;
    logic [REQ_DATA_WIDTH-1:0] vShift_mult_sew [0:3];
    logic [REQ_DATA_WIDTH-1:0] vShift_upper ;
    logic [REQ_DATA_WIDTH-1:0] vShift_vd10 ;
    logic [5:0] vShift_inShift ;
    logic vShiftR64 ;
    logic vShift_orTop ;
    logic [REQ_DATA_WIDTH-1:0] vShift_cmpl_sew [0:3];
    logic [1:0] vWiden_sew, vAdd_sew, vMul_sew, vNarrow_sew;
    logic [REQ_BYTE_EN_WIDTH-1:0] vSlide_outBe, vWiden_be, vNarrow_be, vMCmp_outBe, vRed_outBe;
    logic vMinMax_opSel, vSlide_opSel;
    logic vAdd_outMask, vAndOrXor_outMask;
    logic vSigned_op0, vSigned_op1;
    logic vSlide_insert ; //TODO: assign something
    logic [7:0] vSlide_off, vSlide_outOff;
    logic [2:0] vSlide_shift;

    logic [11:0] vStartIdx;

    logic [RESP_DATA_WIDTH-1:0] vMerge_outVec, vRed_outVec, vMove_outVec, vID_outVec, vFirst_Popc_outVec, vAdd_outVec, vAndOrXor_outVec, vMul_outVec, vSlide_outVec, vNarrow_outVec, fxp_out;
    logic vMerge_outValid, vRed_outValid, vMove_outValid, vID_outValid, vFirst_Popc_outValid, vAdd_outValid, vAndOrXor_outValid, vMul_outValid, vSlide_outValid, vNarrow_outValid;
    logic vMove_outWReg;
    logic [1:0] vRedAndOrXor_opSel, vRedSum_min_max_opSel;
    logic [2:0] vRed_opSel;
    logic [2:0] vMask_opSel;
    logic vFirst_Popc_opSel;
    logic vMove_en, vMerge_en, vMOP_en, vFirst_Popc_en, vRedAndOrXor_en, vRedSum_min_max_en, vMCmp_en, vAdd_en, vMinMax_en, vAndOrXor_en, vMul_en, vSlide_en, vID_en, vNarrow_en, vWiden_en, vAAdd_en, vAddSubCarry_en, vSShift_en, vMoveXS_en, vMoveSX_en, vMoveVY_en, vSMul_en, vMoveWhole_en;
    logic vMul_outNarrow;

    logic [REQ_ADDR_WIDTH-1:0] vAdd_outAddr, vAndOrXor_outAddr, vMul_outAddr, vSlide_outAddr, vMerge_outAddr, vRed_outAddr, vID_outAddr, vFirst_Popc_outAddr;

    logic [REQ_BYTE_EN_WIDTH-1:0] vAAdd_vd, vAAdd_vd1, vMul_vd, vMul_vd1, vMul_vd10;

    logic vMove_outSca;

    logic vAAdd_outFXP, vMul_outFXP;

    assign req_ready = 1'b1; //TODO: control

    generate
    if (AND_OR_XOR_ENABLE) begin : and_or_xor_opsel
      if (VEC_MOVE_ENABLE) begin
        if (WHOLE_REG_ENABLE) begin
          assign vMoveWhole_en = req_insn inside {VMV_1_R_V, VMV_1_R_V, VMV_2_R_V, VMV_4_R_V, VMV_8_R_V};
        end else begin
          assign vMoveWhole_en = 1'b0;
        end

        assign vMoveSX_en = req_insn inside {VMV_SX};
        assign vMoveXS_en = req_insn inside {VMV_XS};
        assign vMoveVY_en = req_insn inside {VMV_VV, VMV_VX, VMV_VI} & req_mask;
        assign vMove_en   = (vMoveVY_en | vMoveWhole_en | vMoveSX_en | vMoveXS_en);
      end else begin
        assign vMoveXS_en = 1'b0;
        assign vMoveSX_en = 1'b0;
        assign vMoveVY_en = 1'b0;
        assign vMove_en   = 1'b0;
        assign vMoveWhole_en = 1'b0;
      end

      assign vAndOrXor_en = req_valid & (req_insn inside {VAND_VV, VAND_VX, VAND_VI, VOR_VV, VOR_VX, VOR_VI, VXOR_VV, VXOR_VX, VXOR_VI} | vMove_en | vMOP_en);
      assign vAndOrXor_in0 = (vMoveXS_en | vMoveWhole_en) ? req_data1 : req_data0;
      assign vAndOrXor_in1 = vMove_en ? vAndOrXor_in0 : req_data1;
      assign vAndOrXor_opSel = vMove_en ? 3'b010 : req_func_id[2:0];
    end

    if (MASK_ENABLE_EXT) begin
      assign vMerge_en = req_valid & req_insn inside {VMERGE_VV, VMERGE_VX, VMERGE_VI};
    end else begin
      assign vMerge_en = 1'b0;
    end

    if (ADD_SUB_ENABLE) begin : add_sub_in
      assign vID_en = req_valid & req_insn inside {VID_V};

      assign vAdd_en = req_valid & (req_insn inside {VADD_VV, VADD_VX, VADD_VI, VSUB_VV, VSUB_VX, VRSUB_VX, VRSUB_VI, VMINU_VV, VMINU_VX, VMIN_VV, VMIN_VX, VMAXU_VV, VMAXU_VX, VMAX_VV, VMAX_VX, VWADDU_VV, VWADDU_VX, VWADD_VV, VWADD_VX, VWSUBU_VV, VWSUBU_VX, VWSUB_VV, VWSUB_VX} | vAAdd_en | vMCmp_en | vAddSubCarry_en);
  

      if (MIN_MAX_ENABLE) begin
        assign vMinMax_en = req_insn inside {VMINU_VV, VMINU_VX, VMIN_VV, VMIN_VX, VMAXU_VV, VMAXU_VX, VMAX_VV, VMAX_VX, VREDMINU_VS, VREDMIN_VS, VREDMAXU_VS, VREDMAX_VS};
        assign vMinMax_opSel = req_func_id[1];
      end else begin
        assign vMinMax_en = 1'b0;
        assign vMinMax_opSel = 1'b0;
      end

      if (FXP_ENABLE) begin
        assign vAAdd_en = req_insn inside {VAADDU_VV, VAADDU_VX, VAADD_VV, VAADD_VX, VASUBU_VV, VASUBU_VX, VASUB_VV, VASUB_VX};
      end else begin
        assign vAAdd_en = 1'b0;
      end

      assign vAdd_sew = vWiden_en ? vWiden_sew : req_sew;

      assign vAdd_in0 = vWiden_en ? vWiden_in0 : req_data0;
      assign vAdd_in1 = vWiden_en ? vWiden_in1 : req_data1;

      assign vAdd_opSel = (req_func_id[2] | vMCmp_en) ? 2'b10 : req_func_id[1:0];

      if (MASK_ENABLE_EXT) begin
        assign vAddSubCarry_en = req_insn inside {VADC_VV, VADC_VX, VADC_VI, VMADC_VV, VMADC_VX, VMADC_VI, VSBC_VV, VSBC_VX, VMSBC_VV, VMSBC_VX};
      end else begin
        assign vAddSubCarry_en = 1'b0;
      end

      assign vSigned_op0 = req_func_id[0];
    end


    if (REDUCTION_ENABLE) begin : red_opsel
      assign vRedAndOrXor_en = req_valid & req_insn inside {VREDAND_VS, VREDOR_VS, VREDXOR_VS};
      assign vRedSum_min_max_en = req_valid & req_insn inside {VREDSUM_VS, VREDMINU_VS, VREDMIN_VS, VREDMAXU_VS, VREDMAX_VS};
      assign vRed_opSel = req_func_id[2:0];
    end else begin
      assign vRedAndOrXor_en = 1'b0;
      assign vRedSum_min_max_en = 1'b0;
    end

    if (MULT_ENABLE) begin : mul_in
      assign vMul_en = req_valid & req_insn inside {VSLL_VV, VSLL_VX, VSLL_VI, VSRL_VV, VSRL_VX, VSRL_VI, VSRA_VV, VSRA_VX, VSRA_VI, VNSRL_VV, VNSRL_VX, VNSRL_VI, VSSRL_VV, VSSRL_VX, VSSRL_VI, VSSRA_VV, VSSRA_VX, VSSRA_VI, VMUL_VV, VMUL_VX, VMULH_VV, VMULH_VX, VSMUL_VV, VSMUL_VX, VWMUL_VV, VWMUL_VX, VWMULSU_VV, VWMULSU_VX};

      if (FXP_ENABLE) begin
        assign vSShift_en = req_insn inside {VSSRL_VV, VSSRL_VX, VSSRL_VI, VSSRA_VV, VSSRA_VX, VSSRA_VI};
        assign vSMul_en = req_insn inside {VSMUL_VV, VSMUL_VX};
      end else begin
        assign vSShift_en = 1'b0;
        assign vSMul_en = 1'b0;
      end

      if (WIDEN_MUL_ENABLE) begin
        assign vMul_sew = vWiden_en ? vWiden_sew : req_sew;
        assign vMul_in0 = vWiden_en ? vWiden_in1 : vMul_vec0;
        assign vMul_in1 = vWiden_en ? vWiden_in0 : vMul_vec1;
      end else begin
        assign vMul_sew = req_sew;

        assign vMul_in0 = vMul_vec0;
        assign vMul_in1 = vMul_vec1;
      end
    end

    if (SLIDE_ENABLE) begin : slide_in
      assign vSlide_insert = vSlide_en & req_insn inside {VSLIDE1UP_VX, VSLIDE1DOWN_VX};
      assign vSlide_en = req_valid & req_insn inside {VSLIDE1UP_VX, VSLIDE1DOWN_VX, VSLIDEUP_VX, VSLIDEUP_VI, VSLIDEDOWN_VX, VSLIDEDOWN_VI};
      assign vSlide_in1 = vSlide_insert ? req_data0 : 'b0; // for slide 1 only
      assign vSlide_opSel = req_func_id[0];

      if (SLIDE_N_ENABLE) begin
        assign vSlide_shift = vSlide_insert ? (3'b1 << req_sew) : req_data0[2:0] << req_sew;
        assign vSlide_off = vSlide_insert ? 'h0 : req_data0 >> (3 - req_sew);
      end else begin
        assign vSlide_shift = (3'b1 << req_sew);
        assign vSlide_off = 'h0;
      end
    end else begin
      assign vSlide_en = 'b0;
    end

    if (MASK_ENABLE) begin : mask_opsel
      assign vMCmp_en = req_insn inside {VMSEQ_VV, VMSEQ_VX, VMSEQ_VI, VMSNE_VV, VMSNE_VX, VMSNE_VI, VMSLE_VV, VMSLE_VX, VMSLE_VI, VMSLEU_VV, VMSLEU_VX, VMSLEU_VI, VMSLT_VV, VMSLT_VX, VMSGT_VX, VMSGT_VI};
      assign vMOP_en = req_insn inside {VMANDNOT_MM, VMAND_MM, VMOR_MM, VMXOR_MM, VMORNOT_MM, VMNAND_MM, VMNOR_MM, VMXNOR_MM};

      if (MASK_ENABLE_EXT) begin
        assign vFirst_Popc_en = req_valid & req_insn inside {VCPOP_M, VFIRST_M};
        assign vFirst_Popc_opSel= req_insn inside {VFIRST_M};
      end
      assign vMask_opSel = req_func_id[2:0];
    end else begin
      assign vMOP_en = 'b0;
      assign vMCmp_en = 'b0;
      assign vMask_opSel = 'h0;
    end

    if(WIDEN_ADD_ENABLE | WIDEN_MUL_ENABLE) begin : widen
      if (WIDEN_MUL_ENABLE) begin
        assign vSigned_op1 = (req_func_id[3] & req_func_id[1]) | req_func_id[0];
      end else begin
        assign vSigned_op1 = req_func_id[0];
      end

      assign vWiden_en = req_insn inside {VWADDU_VV, VWADDU_VX, VWADD_VV, VWADD_VX, VWSUBU_VV, VWSUBU_VX, VWSUB_VV, VWSUB_VX, VWMUL_VV, VWMUL_VX, VWMULSU_VV, VWMULSU_VX} & req_sew != 2'b11;

      vWiden #(.REQ_BYTE_EN_WIDTH(REQ_BYTE_EN_WIDTH), .RESP_DATA_WIDTH(RESP_DATA_WIDTH)) 
      vWiden_0 ( .in_vec0 (req_data0 ), .in_vec1 (req_data1 ), .in_turn (turn ), .in_be (req_be ), .in_signed0 (vSigned_op0), .in_signed1 (vSigned_op1), .in_sew (req_sew ), .out_be (vWiden_be ), .out_vec0 (vWiden_in0 ), .out_vec1 (vWiden_in1 ), .out_sew (vWiden_sew ));
    end else begin
      assign vWiden_en = 0;

      assign vWiden_be = 0;
      assign vWiden_in0 = 0;
      assign vWiden_in1 = 0;
      assign vWiden_sew = 0;
    end

    if(NARROW_ENABLE) begin : narrow
      assign vNarrow_en = req_valid & req_insn inside {VNSRL_VV, VNSRL_VX, VNSRL_VI} & req_sew != 2'b00;

      vNarrow #( .REQ_BYTE_EN_WIDTH(REQ_BYTE_EN_WIDTH), .REQ_ADDR_WIDTH(REQ_ADDR_WIDTH), .RESP_DATA_WIDTH(RESP_DATA_WIDTH), .ENABLE_64_BIT(ENABLE_64_BIT)) 
      vNarrow_0 ( .clk (clk ), .rst (rst ), .in_vec0 (vMul_outVec ), .in_valid (vMul_outNarrow ), .in_sew (s5_sew ), .in_be (s5_be ), .out_be (vNarrow_be ), .out_vec (vNarrow_outVec ), .out_valid (vNarrow_outValid ), .out_sew (vNarrow_sew ));
    end else begin
      assign vNarrow_en = 1'b0;
      assign vNarrow_sew = 'h0;
      assign vNarrow_be = 'h0;
      assign vNarrow_outVec = 'h0;
      assign vNarrow_outValid = 'b0;
    end

    genvar i,j;

    if(SHIFT_ENABLE) begin : shift
      for (j = 0; j < 3; j = j + 1) begin
        for (i = 0; i < (REQ_DATA_WIDTH >> (j+3)); i = i + 1) begin
          assign vShift_mult_sew[j][i*(1 << (j+3)) +: (1 << (j+3))] = 2**(vShift_cmpl_sew[j][i*(1 << (j+3)) +: (1 << (j+3))]);
        end
      end

      if (SHIFT64_ENABLE) begin : shift64
        if (EN_128_MUL) begin
          assign vShiftR64 = 'b0;
          assign vShift_orTop = 'b0;
          assign vShift_vd10 = 'b0;
          assign vShift_inShift = 'h0;

          assign vMul_vec0 = req_data1;

          for (i = 0; i < REQ_DATA_WIDTH/64; i = i + 1) begin
            assign vShift_cmpl_sew[3][i*64 +: 64] = req_func_id[3] ? 64 - req_data0[i*64 +: 64] : req_data0[i*64 +: 64];
          end
        end else begin
          assign vShiftR64 = req_func_id[3] & (&req_sew);

          for (i = 0; i < (REQ_DATA_WIDTH >> 6); i = i + 1) begin
            assign vShift_upper[i*64 +: 64] = vShift_orTop ? req_data1 : {32'b0,req_data1[(i*64 + 32) +: 32]}; // upper 32b

            if (FXP_ENABLE) begin
              assign vShift_vd10[i*64 +: 64] = vShift_orTop ? 'h0 : (|req_data1[(i*64) +: 32]); // lower 32b
            end else begin
              assign vShift_vd10 = 'h0;
            end
          end

          assign vShift_orTop = (req_data0 < 32);

          assign vMul_vec0 = vShiftR64 ? vShift_upper : req_data1;

          assign vShift_inShift = vShiftR64 ? req_data0[5:0] - 7 : 'h0; // upper bits shift by 0-25 bits

          for (i = 0; i < REQ_DATA_WIDTH/64; i = i + 1) begin
            assign vShift_cmpl_sew[3][i*64 +: 64] = req_func_id[3] ? (req_data0[i*64 +: 64] < 32 ? 32 - req_data0[i*64 +: 64] : 64 - req_data0[i*64 +: 64]) : req_data0[i*64 +: 64];
          end
        end
        for (i = 0; i < REQ_DATA_WIDTH/64; i = i + 1) begin
          assign vShift_mult_sew[3][i*64 +: 64] = 2**(vShift_cmpl_sew[3][i*64 +: 64]);
        end

        assign vMul_vec1 = (req_func_id[2:0] != 3'b111 && req_op_mnr[1] == req_op_mnr[0]) ? vShift_mult_sew[(req_sew)] : req_data0;
      end else begin
        assign vShiftR64 = 'b0;
        assign vShift_orTop = 'b0;
        assign vShift_vd10 = 'b0;
        assign vShift_inShift = 'h0;
        assign vMul_vec0 = req_data1;
        assign vShift_cmpl_sew[3] = 0;
        assign vShift_mult_sew[3] = 'h0;

        if (NARROW_ENABLE) begin
          assign vMul_vec1 = req_op_mnr[1] == req_op_mnr[0] ? vShift_mult_sew[req_sew] : req_data0; // srl/sra/sll use IV[V/X/I] encoding
        end
      end

      if (MULH_SR_32_ENABLE | MULH_SR_ENABLE) begin : mulh_sr
        if (MULH_SR_32_ENABLE) begin
          for (i = 0; i < REQ_DATA_WIDTH/32; i = i + 1) begin
            assign vShift_cmpl_sew[2][i*32 +: 32] = req_func_id[3] ? 32 - req_data0[i*32 +: 32] : req_data0[i*32 +: 32];
          end
        end else begin
          assign vShift_cmpl_sew[2] = req_data0;
        end

        for (i = 0; i < REQ_DATA_WIDTH/8; i = i + 1) begin
          assign vShift_cmpl_sew[0][i*8 +: 8] = req_func_id[3] ? 8 - req_data0[i*8 +: 8] : req_data0[i*8 +: 8];
        end
        for (i = 0; i < REQ_DATA_WIDTH/16; i = i + 1) begin
          assign vShift_cmpl_sew[1][i*16 +: 16] = req_func_id[3] ? 16 - req_data0[i*16 +: 16] : req_data0[i*16 +: 16];
        end

        assign vMul_opSel = (req_func_id[5:3] == 3'b101 && req_op_mnr[1] == req_op_mnr[0]) ? {req_func_id[0],1'b0} : req_func_id[1:0]; // opsel is normal except for shift right
      end else begin
        for (j = 0; j < 3; j = j + 1) begin
          assign vShift_cmpl_sew[j] = req_data0;
        end

        assign vMul_opSel = 2'b01; // only one option for mul/sll
      end
    end
    else begin
      if (MULT_ENABLE) begin
        assign vMul_vec1 = req_data0;
        assign vMul_vec0 = req_data1;
        assign vMul_opSel = 2'b01;
        assign vShift_orTop = 0;
        assign vShift_vd10 = 0;
        assign vShiftR64 = 0;
        assign vShift_inShift = 0;
      end
    end

    if(ADD_SUB_ENABLE) begin : add_sub
      assign vStartIdx = req_vr_idx << ('h3 - req_sew);

      vID #( .REQ_BYTE_EN_WIDTH(REQ_BYTE_EN_WIDTH), .REQ_ADDR_WIDTH(REQ_ADDR_WIDTH), .RESP_DATA_WIDTH(RESP_DATA_WIDTH), .ENABLE_64_BIT(ENABLE_64_BIT)) 
      vID_0 ( .clk (clk ), .rst (rst ), .in_sew (req_sew ), .in_valid (vID_en ), .in_addr (req_addr ), .in_start_idx (vStartIdx ), .out_vec (vID_outVec ), .out_valid (vID_outValid ), .out_addr (vID_outAddr ));

      vAdd_min_max # ( .REQ_DATA_WIDTH (REQ_DATA_WIDTH), .RESP_DATA_WIDTH(RESP_DATA_WIDTH), .REQ_ADDR_WIDTH (REQ_ADDR_WIDTH), .SEW_WIDTH (SEW_WIDTH), .OPSEL_WIDTH (9), .MIN_MAX_ENABLE (MIN_MAX_ENABLE), .MASK_ENABLE (MASK_ENABLE), .FXP_ENABLE (FXP_ENABLE), .MASK_ENABLE_EXT(MASK_ENABLE_EXT), .ENABLE_64_BIT (ENABLE_64_BIT)) 
      vAdd_0 ( .clk (clk ), .rst (rst ), .in_vec0 (vAdd_in0 ), .in_vec1 (vAdd_in1 ), .in_sew (vAdd_sew ), .in_valid (vAdd_en ), .in_opSel ({vMCmp_en,vMask_opSel,vMinMax_en,vMinMax_opSel,vSigned_op0,vAdd_opSel}), .in_addr (req_addr ), .in_start_idx(vStartIdx[5:0]), .in_req_start(req_start ), .in_req_end (req_end ), .in_be (req_be ), .in_avg (vAAdd_en ), .in_carry (vAddSubCarry_en), .in_mask (~req_mask ), .out_vec (vAdd_outVec ), .out_valid (vAdd_outValid ), .out_addr (vAdd_outAddr ), .out_be (vMCmp_outBe ), .out_mask (vAdd_outMask ), .out_vd (vAAdd_vd ), .out_vd1 (vAAdd_vd1 ), .out_fxp (vAAdd_outFXP ));
    end else begin
      assign vStartIdx = 'h0;
      assign vAdd_outVec = 'h0;
      assign vAdd_outValid = 1'b0;
      assign vMCmp_outBe = 'h0;
      assign vAdd_outMask = 1'b0;
      assign vID_outVec = 'h0;
      assign vID_outAddr = 'h0;
      assign vID_outValid = 1'b0;
    end

    if(AND_OR_XOR_ENABLE) begin : and_or_xor
      vAndOrXor # ( .REQ_DATA_WIDTH (REQ_DATA_WIDTH), .RESP_DATA_WIDTH(RESP_DATA_WIDTH), .REQ_ADDR_WIDTH (REQ_ADDR_WIDTH), .OPSEL_WIDTH (2), .WHOLE_REG_ENABLE(WHOLE_REG_ENABLE), .VEC_MOVE_ENABLE(VEC_MOVE_ENABLE), .MASK_ENABLE (MASK_ENABLE)) 
      vAndOrXor_0 ( .clk (clk ), .rst (rst ), .in_vec0 (vAndOrXor_in0 ), .in_vec1 (vAndOrXor_in1 ), .in_opSel (vAndOrXor_opSel ), .in_valid (vAndOrXor_en ), .in_addr (req_addr ), .in_w_reg (vMoveWhole_en ), .in_sca (vMoveXS_en ), .in_mask (vMOP_en ), .out_vec (vAndOrXor_outVec ), .out_valid (vAndOrXor_outValid ), .out_addr (vAndOrXor_outAddr ), .out_w_reg (vMove_outWReg ), .out_sca (vMove_outSca ), .out_mask (vAndOrXor_outMask ));
    end else begin
      assign vAndOrXor_outVec = 0;
      assign vAndOrXor_outValid = 0;
      assign vAndOrXor_outAddr = 0;
      assign vAndOrXor_outMask = 0;
      assign vMove_outWReg = 0;
      assign vMove_outSca = 0;
    end

    if(MULT_ENABLE) begin : mult
      vMul # ( .REQ_DATA_WIDTH (REQ_DATA_WIDTH), .RESP_DATA_WIDTH (RESP_DATA_WIDTH), .REQ_ADDR_WIDTH (REQ_ADDR_WIDTH), .SEW_WIDTH (SEW_WIDTH), .MULH_SR_ENABLE (MULH_SR_ENABLE), .WIDEN_MUL_ENABLE (WIDEN_MUL_ENABLE), .NARROW_ENABLE (NARROW_ENABLE), .MULH_SR_32_ENABLE (MULH_SR_32_ENABLE), .MUL64_ENABLE (MULT64_ENABLE), .FXP_ENABLE (FXP_ENABLE), .ENABLE_64_BIT (ENABLE_64_BIT), .EN_128_MUL (EN_128_MUL), .OPSEL_WIDTH (2)) 
      vMul_0 ( .clk (clk ), .rst (rst ), .in_vec0 (vMul_in0 ), .in_vec1 (vMul_in1 ), .in_sew (vMul_sew ), .in_valid (vMul_en ), .in_opSel (vMul_opSel ), .in_widen (vWiden_en ), .in_addr (req_addr ), .in_fxp_s (vSShift_en ), .in_fxp_mul (vSMul_en ), .in_sr_64 (vShiftR64 ), .in_or_top (vShift_orTop ), .in_vd10 (vShift_vd10 ), .in_shift (vShift_inShift ), .in_narrow (vNarrow_en ), .out_vec (vMul_outVec ), .out_valid (vMul_outValid ), .out_addr (vMul_outAddr ), .out_vd (vMul_vd ), .out_vd1 (vMul_vd1 ), .out_vd10 (vMul_vd10 ), .out_narrow (vMul_outNarrow ), .out_fxp (vMul_outFXP )); 
    end else begin
      assign vMul_outVec = 'h0;
      assign vMul_outValid = 'b0;
      assign vMul_outAddr = 'h0;
    end

    if(SLIDE_ENABLE) begin : slide
      vSlide #( .REQ_DATA_WIDTH (REQ_DATA_WIDTH), .RESP_DATA_WIDTH(RESP_DATA_WIDTH), .REQ_ADDR_WIDTH(REQ_ADDR_WIDTH), .ENABLE_64_BIT(ENABLE_64_BIT), .SLIDE_N_ENABLE(SLIDE_N_ENABLE)) 
      vSlide_0 ( .clk (clk ), .rst (rst ), .in_vec0 (req_data1 ), .in_vec1 (vSlide_in1 ), .in_be (req_be ), .in_off (vSlide_off ), .in_shift (vSlide_shift ), .in_valid (vSlide_en ), .in_start (req_start ), .in_end (req_end ), .in_opSel (vSlide_opSel ), .in_insert (vSlide_insert ), .in_addr (req_addr ), .out_be (vSlide_outBe ), .out_vec (vSlide_outVec ), .out_valid (vSlide_outValid), .out_addr (vSlide_outAddr ), .out_off (vSlide_outOff ));
    end else begin
      assign vSlide_outBe = 0;
      assign vSlide_outValid = 0;
      assign vSlide_outVec = 0;
      assign vSlide_outAddr = 0;
      assign vSlide_outOff = 0;
    end

    if(MASK_ENABLE_EXT) begin : mask
      vMerge # ( .REQ_DATA_WIDTH (REQ_DATA_WIDTH), .RESP_DATA_WIDTH(RESP_DATA_WIDTH), .REQ_ADDR_WIDTH(REQ_ADDR_WIDTH))
      vMerge0( .clk (clk ), .rst (rst ), .in_mask (req_be ), .in_vec0 (req_data0 ), .in_vec1 (req_data1 ), .in_valid (vMerge_en ), .in_addr (req_addr ), .out_vec (vMerge_outVec ), .out_addr (vMerge_outAddr ), .out_valid (vMerge_outValid));

      vFirst_Popc #( .REQ_DATA_WIDTH (REQ_DATA_WIDTH), .RESP_DATA_WIDTH(RESP_DATA_WIDTH), .REQ_ADDR_WIDTH(REQ_ADDR_WIDTH)) 
      vFirstPopc0 ( .clk (clk ), .rst (rst ), .in_m0 (req_data1 ), .in_valid (vFirst_Popc_en ), .in_end (req_end ), .in_addr (req_addr ), .in_start_idx(vStartIdx ), .in_opSel (vFirst_Popc_opSel ), .out_vec (vFirst_Popc_outVec ), .out_addr (vFirst_Popc_outAddr ), .out_valid (vFirst_Popc_outValid )); //MASK???
    end else begin
      assign vMerge_outVec = 0;
      assign vMerge_outValid = 0;
      assign vMerge_outAddr = 0;
      assign vFirst_Popc_outVec = 0;
      assign vFirst_Popc_outValid = 0;
      assign vFirst_Popc_outAddr = 0;
    end

    if(REDUCTION_ENABLE) begin : red
      vReduction #( .REQ_DATA_WIDTH (REQ_DATA_WIDTH), .RESP_DATA_WIDTH(RESP_DATA_WIDTH), .REQ_ADDR_WIDTH (REQ_ADDR_WIDTH), .ENABLE_64_BIT (ENABLE_64_BIT)) 
      vRed0 ( .clk (clk ), .rst (rst ), .in_vec0 (req_data1 ), .in_vec1 (req_data0 ), .in_valid (vRedAndOrXor_en | vRedSum_min_max_en), .in_lop_sum (vRedAndOrXor_en ), .in_start (req_start ), .in_end (req_end ), .in_opSel (vRed_opSel ), .in_sew (req_sew ), .in_addr (req_addr ), .out_vec (vRed_outVec ), .out_valid (vRed_outValid ), .out_addr (vRed_outAddr ), .out_be (vRed_outBe ));
    end
    else begin
      assign vRed_outVec = 0;
      assign vRed_outValid = 0;
      assign vRed_outAddr = 0;
    end

    if (FXP_ENABLE) begin : fxp_round
      fxp_round #(.DATA_WIDTH(REQ_DATA_WIDTH)) 
      fxp (.clk(clk), .rst (rst), .vxrm (s5_vxrm), .in_valid(vAAdd_outFXP | vMul_outFXP), .vec_in(vAdd_outVec | vMul_outVec), .v_d(vAAdd_vd | vMul_vd), .v_d1(vAAdd_vd1 | vMul_vd1), .v_d10(vAAdd_vd1 | vMul_vd10), .vec_out(fxp_out));

      always @(posedge clk) begin
        if (rst) begin
          s0_vxrm <= 'h0;
          s1_vxrm <= 'h0;
          s2_vxrm <= 'h0;
          s3_vxrm <= 'h0;
          s4_vxrm <= 'h0;
          s5_vxrm <= 'h0;
        end else begin
          s0_vxrm <= req_vxrm;
          s1_vxrm <= s0_vxrm;
          s2_vxrm <= s1_vxrm;
          s3_vxrm <= s2_vxrm;
          s4_vxrm <= s3_vxrm;
          s5_vxrm <= s4_vxrm;
        end
      end
    end else begin
      if (MULT_ENABLE) begin
        assign fxp_out = vAdd_outVec | vMul_outVec;
      end else begin
        if (ADD_SUB_ENABLE) begin
          assign fxp_out = vAdd_outVec;
        end else begin
          assign fxp_out = 0;
        end
      end
    end
    endgenerate

    always @(posedge clk) begin
      if(rst) begin
        turn <= 'b0;

        s0_sew <= 'b0;
        s1_sew <= 'b0;
        s2_sew <= 'b0;
        s3_sew <= 'b0;
        s4_sew <= 'b0;
        s5_sew <= 'b0;
        resp_sew <= 'b0;

        s0_be <= 'b0;
        s1_be <= 'b0;
        s2_be <= 'b0;
        s3_be <= 'b0;
        s4_be <= 'b0;
        s5_be <= 'b0;
        resp_be <= 'b0;

        s0_start <= 'b0;
        s1_start <= 'b0;
        s2_start <= 'b0;
        s3_start <= 'b0;
        s4_start <= 'b0;
        s5_start <= 'b0;
        resp_start <= 'b0;

        s0_end <= 'b0;
        s1_end <= 'b0;
        s2_end <= 'b0;
        s3_end <= 'b0;
        s4_end <= 'b0;
        s5_end <= 'b0;
        resp_end <= 'b0;

        s0_off <= 'b0;
        s1_off <= 'b0;
        s2_off <= 'b0;
        s3_off <= 'b0;
        s4_off <= 'b0;
        s5_off <= 'b0;
        resp_off <= 'b0;

        resp_mask_out <= 'b0;
        resp_sca_out <= 'b0;
        resp_whole_reg <= 'b0;
        resp_narrow <= 'b0;
        resp_data <= 'b0;
        resp_valid <= 'b0;

        s0_out_addr <= 'h0;
        s1_out_addr <= 'h0;
        s2_out_addr <= 'h0;
        s3_out_addr <= 'h0;
        s4_out_addr <= 'h0;
        s5_out_addr <= 'h0;
        resp_addr <= 'h0;
      end else begin
        s0_sew <= vWiden_en ? vWiden_sew : req_sew;
        s1_sew <= s0_sew;
        s2_sew <= s1_sew;
        s3_sew <= s2_sew;
        s4_sew <= s3_sew;
        s5_sew <= s4_sew;
        if(NARROW_ENABLE) begin
          resp_sew <= vNarrow_outValid ? vNarrow_sew : s5_sew;
        end else begin
          resp_sew <= s5_sew;
        end

        // TODO pipe these through modules instead, so timing of outputs is guaranteed
        s0_be <= (req_valid & ~vSlide_en & ~vMCmp_en & ~vRedAndOrXor_en & ~vRedSum_min_max_en) ? (vWiden_en ? vWiden_be : req_be) : 'h0;
        s1_be <= s0_be;
        s2_be <= s1_be;
        s3_be <= s2_be;
        s4_be <= s3_be;
        s5_be <= s4_be;

        s0_start <= req_start & req_valid;
        s1_start <= s0_start;
        s2_start <= s1_start;
        s3_start <= s2_start;
        s4_start <= s3_start;
        s5_start <= s4_start;
        resp_start <= s5_start;

        s0_end <= req_end & req_valid;
        s1_end <= s0_end;
        s2_end <= s1_end;
        s3_end <= s2_end;
        s4_end <= s3_end;
        s5_end <= s4_end;
        resp_end <= s5_end;

        s0_off <= req_valid ? req_off : 'h0;
        s1_off <= s0_off;
        s2_off <= s1_off;
        s3_off <= s2_off;
        s4_off <= s3_off;
        s5_off <= s4_off;
        if (SLIDE_N_ENABLE) begin
          resp_off <= vSlide_outValid ? vSlide_outOff : s5_off;
        end else begin
          resp_off <= s5_off;
        end

        s0_out_addr <= req_valid ? req_addr : 'h0;
        s1_out_addr <= s0_out_addr;
        s2_out_addr <= s1_out_addr;
        s3_out_addr <= s2_out_addr;
        s4_out_addr <= s3_out_addr;
        s5_out_addr <= s4_out_addr;
        resp_addr <= s5_out_addr;

        if (NARROW_ENABLE) begin
          resp_be <= vNarrow_outValid ? vNarrow_be : (vSlide_outBe | s5_be | vMCmp_outBe | vRed_outBe);
          resp_narrow <= vNarrow_outValid;
        end else begin
          resp_be <= (vSlide_outBe | s5_be | vMCmp_outBe | vRed_outBe);
          resp_narrow <= 1'b0;
        end

        resp_valid <= vAdd_outValid | vAndOrXor_outValid| vMul_outValid | vSlide_outValid | vMerge_outValid | vFirst_Popc_outValid | vRed_outValid | vID_outValid;

        resp_data <= vNarrow_outValid ? vNarrow_outVec : (vAndOrXor_outVec | vSlide_outVec| vMerge_outVec | vFirst_Popc_outVec | vRed_outVec | vID_outVec | fxp_out);

        resp_mask_out <= (vAndOrXor_outValid & vAndOrXor_outMask) | (vAdd_outValid & vAdd_outMask);

        resp_sca_out <= vFirst_Popc_outValid| vMove_outSca;

        if (WHOLE_REG_ENABLE) begin
          resp_whole_reg <= vMove_outWReg;
        end else begin
          resp_whole_reg <= 'h0;
        end


        if(req_end)
          turn <= 0;
        else if (vWiden_en)
          turn <= ~turn;
        else
          turn <= 0;
      end
    end
    endmodule
