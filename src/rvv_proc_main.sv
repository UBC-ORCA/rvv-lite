`define MIN(a,b) {(a > b) ? b : a}

(* keep_hierarchy = "yes" *) module rvv_proc_main 
  import opcodes::*;
  import cva5_config::*;
  import riscv_types::*;
  import cva5_types::*;
  import cxu_types::*;
  import cx_dma_types::*;
  #(
    parameter VLEN                = 16384, // vector length in bits
    parameter XLEN                = 32, // not sure, data width maybe?
    parameter INSN_WIDTH          = 32, // width of a single instruction
    parameter DATA_WIDTH          = 64,
    parameter ADDR_WIDTH          = 5, // 5 bits for 32 vector regs
    parameter MEM_ADDR_WIDTH      = 32, // We need to get this from VexRiscV
    parameter MEM_DATA_WIDTH      = DATA_WIDTH,
    parameter NUM_VREGS           = 2**ADDR_WIDTH, // number of available vector registers

    parameter STATE_ID_WIDTH      = 1,
    parameter MAX_READ_IN_FLIGHT  = 1,
    parameter MAX_WRITE_IN_FLIGHT = 1,

    parameter ENABLE_64_BIT       = 1,
    parameter AND_OR_XOR_ENABLE   = 1,  // a1b
    parameter ADD_SUB_ENABLE      = 1,  // a1b
    parameter MIN_MAX_ENABLE      = 1,  // a1c
    parameter MASK_ENABLE         = 1,  // a1d
    parameter VEC_MOVE_ENABLE     = 1,  // a1e
    parameter WHOLE_REG_ENABLE    = 1,  // a1f
    parameter SLIDE_ENABLE        = 1,  // a1g
    parameter WIDEN_ADD_ENABLE    = 1,  // a2
    parameter REDUCTION_ENABLE    = 1,  // a3
    parameter MULT_ENABLE         = 1,  // a4a
    parameter SHIFT_ENABLE        = 1,  // a4a   
    parameter MULH_SR_ENABLE      = 1,  // a4b
    parameter MULH_SR_32_ENABLE   = 1,  // a4c
    parameter WIDEN_MUL_ENABLE    = 1,  // a4d
    parameter NARROW_ENABLE       = 1,  // a4d
    parameter SLIDE_N_ENABLE      = 1,  // a5
    parameter MULT64_ENABLE       = 0,  // a6
    parameter SHIFT64_ENABLE      = 0,  // a6
    parameter FXP_ENABLE          = 1,  // a7
    parameter MASK_ENABLE_EXT     = 1,  // b1
    parameter EN_128_MUL          = 0,
    parameter NUM_PERF_COUNTERS   = 2
  )
  (
    input  logic clk,
    input  logic rst,
    output logic req_ready,
    input  logic req_valid,
    input  logic [STATE_ID_WIDTH-1:0] req_state,
    input  logic [INSN_WIDTH-1:0] req_insn,
    input  read_attr_t req_read_attr,
    input  track_id_t  req_track_id,
    input  logic [3-1:0] req_vxrm,
    input  logic [XLEN-1:0] req_data0,
    input  logic [XLEN-1:0] req_data1,
    output logic resp_valid,
    output logic [XLEN-1:0] resp_data,
    /* Stream interfaces */
    gen_interface.master    m_read_req,
    gen_interface.master    m_write_req,
    stream_interface.slave  s_read_stream,
    stream_interface.master m_write_stream,
    /* Scoreboard */
    output logic read_scoreboard [NUM_VREGS],
    output logic [32-1:0] perf_cnts [NUM_PERF_COUNTERS]
  );

    genvar i, q, r;

    localparam NUM_QUEUES = 2**STATE_ID_WIDTH;
    localparam NUM_STAGES = 7;

    localparam VLMAX        = VLEN/8;
    localparam VL_BITS      = $clog2(VLMAX)+1;
    localparam VLEN_B       = VLEN/8;
    localparam VLEN_B_BITS  = $clog2(VLEN_B);
    localparam DW_B         = DATA_WIDTH/8;
    localparam DW_B_BITS    = $clog2(DW_B);
    localparam OFF_BITS     = $clog2(VLEN/DATA_WIDTH); // max value is 256 (16384/64)

    typedef enum bit {
      READ  = 0,
      WRITE = 1
    } mem_port_t;

    typedef enum bit [$clog2(NUM_RESP_PORTS)-1:0] {
      ALU   = 0,
      CFG   = 1,
      LOAD  = 2,
      STORE = 3
    } resp_port_t;

    logic vr_rd_valid_1;
    logic vr_rd_valid_2;
    logic vr_rd_valid_3;
    logic vr_rd_start_3;
    logic vr_rd_end_3;
    logic [DW_B-1:0] vr_wr_en;
    logic [DW_B-1:0] vr_ld_en;
    logic [DW_B-1:0] vr_in_en_1;
    logic [DW_B-1:0] vr_in_en_2;
    
    logic [DW_B-1:0] mask_be;

    logic vm_rd_en;
    logic [DW_B-1:0] vm_wr_en;

    logic [ADDR_WIDTH-1:0] vr_in_addr_1;
    logic [ADDR_WIDTH-1:0] vr_in_addr_2;

    logic [OFF_BITS-1:0] vr_in_off_1;
    logic [OFF_BITS-1:0] vr_in_off_2;

    logic [OFF_BITS-1:0] vm_in_off;
    logic [OFF_BITS-1:0] vm_rd_off;

    logic [ADDR_WIDTH-1:0] vm_in_addr;
    logic [ADDR_WIDTH-1:0] vm_rd_addr;

    logic [DATA_WIDTH-1:0] vr_in_data_1;
    logic [DATA_WIDTH-1:0] vr_in_data_2;
    logic [DATA_WIDTH-1:0] vr_ld_data_in;
    logic [DATA_WIDTH-1:0] vr_rd_data_out_1;
    logic [DATA_WIDTH-1:0] vr_rd_data_out_2;
    logic [DATA_WIDTH-1:0] vr_rd_data_out_3;
    logic [DATA_WIDTH-1:0] vr_wr_data_in;

    logic [DATA_WIDTH-1:0] vm_rd_data_out;

    logic insn_valid_f;
    logic [STATE_ID_WIDTH-1:0] state_id_f;
    logic [INSN_WIDTH-1:0] insn_in_f;
    logic [XLEN-1:0] data_in_1_f;
    logic [XLEN-1:0] data_in_2_f;
    track_id_t track_id_f;
    read_attr_t read_attr_f;
    logic [1:0] vxrm_in_f;

    logic stall;

    logic en_mem_out;

    logic en_vd;
    logic en_ld;

    // value propagation signals
    logic [INSN_WIDTH-1:0] insn_in_d;
    logic [DATA_WIDTH-1:0] sca_data_in_1_d;
    logic [DATA_WIDTH-1:0] sca_data_in_2_d;
    logic [2-1:0] vxrm_in_d;
    logic [STATE_ID_WIDTH-1:0] state_id_d;
    track_id_t track_id_d;

    logic [INSN_WIDTH-1:0] insn_in_m;
    logic [2-1:0] opcode_mnr_m;
    logic [ADDR_WIDTH-1:0] dest_m; // rd, vd, or vs3 -- TODO make better name lol

    logic [XLEN-1:0] out_avl;
    logic [XLEN-1:0] out_data_e;
    logic out_ack_e;
    logic out_ack_ld;
    logic out_ack_st;
    logic out_ack_cfg;

    logic [VLEN_B_BITS+1-1:0] reg_count;

    logic alu_req_valid;
    logic [2-1:0] alu_req_vxrm;
    
    logic [DATA_WIDTH-1:0] alu_req_data0;
    logic [DATA_WIDTH-1:0] alu_req_data1;
    logic [DATA_WIDTH-1:0] alu_resp_data;

    logic [ADDR_WIDTH-1:0] alu_resp_addr;
    logic [OFF_BITS-1:0] alu_req_off;
    logic [OFF_BITS-1:0] alu_resp_off;
    logic alu_resp_valid;
    logic [VL_BITS-1:0] alu_resp_vl;
    logic alu_resp_mask;
    logic alu_resp_sca;
    logic [DW_B-1:0] alu_req_be;
    logic [DW_B-1:0] alu_resp_be;
    logic [VLEN_B_BITS+1-1:0] alu_req_vr_idx; // MAX VALUE IS 2047
    logic [VLEN_B_BITS+1-1:0] alu_req_vr_idx_next; // MAX VALUE IS 2047
    logic alu_resp_whole_reg; // whole register insn

    logic hold_reg_group;
    logic no_bubble;

    logic wait_mem;
    logic wait_mem_st;
    logic wait_mem_msk;

    // Detect hazards for operands
    logic haz_vm;
    logic haz_vd;
    logic haz_vs1;
    logic haz_vs2;
    logic haz_vs3;

    logic alu_req_start, alu_req_end;
    logic alu_resp_start, alu_resp_end;
    logic [2-1:0] alu_resp_sew;

    logic [OFF_BITS-1:0] avl_max_off;
    logic [OFF_BITS-1:0] avl_max_off_s;
    logic [OFF_BITS-1:0] avl_max_off_w;
    logic [OFF_BITS-1:0] avl_max_off_l;
    logic [OFF_BITS-1:0] avl_max_off_in_rd;
    logic [OFF_BITS-1:0] avl_max_off_in_wr;
    logic [OFF_BITS-1:0] avl_max_off_in_ld;

    logic [3-1:0] avl_max_reg;
    logic [3-1:0] avl_max_reg_s;
    logic [3-1:0] avl_max_reg_w;
    logic [3-1:0] avl_max_reg_l;
    logic [3-1:0] avl_max_reg_in_rd;
    logic [3-1:0] avl_max_reg_in_wr;
    logic [3-1:0] avl_max_reg_in_ld;

    logic whole_reg_ld;

    logic [DW_B-1:0] avl_be;

    logic alu_resp_narrow;

    logic vr_ld_ack;

    /* AXI */
    // Read address channel
    logic ar_ready;
    logic ar_valid;
    logic [3-1:0] ar_size;
    logic [8-1:0] ar_len;
    logic [STATE_ID_WIDTH+TRACK_ID_WIDTH-1:0] ar_id;
    logic [MEM_ADDR_WIDTH-1:0] ar_addr;

    // Read data channel
    logic r_ready;
    logic r_valid;
    logic r_last;
    logic [DATA_WIDTH-1:0] r_data;
    logic [STATE_ID_WIDTH+TRACK_ID_WIDTH-1:0] r_id;
    logic [2-1:0] r_resp;

    // Write address channel
    logic aw_ready;
    logic aw_valid;
    logic [3-1:0] aw_size;
    logic [8-1:0] aw_len;
    logic [STATE_ID_WIDTH+TRACK_ID_WIDTH-1:0] aw_id;
    logic [MEM_ADDR_WIDTH-1:0] aw_addr;

    // Write data channel
    logic w_ready;
    logic w_valid;
    logic [DATA_WIDTH-1:0] w_data;
    logic [(DATA_WIDTH/8)-1:0] w_strb;
    logic w_last;

    // Write response channel
    logic b_ready;
    logic b_valid;
    logic [STATE_ID_WIDTH+TRACK_ID_WIDTH-1:0] b_id;
    logic [2-1:0] b_resp;

    always_comb begin
      s_read_stream.tready = r_ready;
      r_valid = s_read_stream.tvalid;
      r_last  = s_read_stream.tlast;
      r_data  = s_read_stream.tdata;
      r_id    = s_read_stream.tid;
      r_resp  = '0; //unused
    end

    always_comb begin
      w_ready = m_write_stream.tready;
      m_write_stream.tvalid = w_valid;
      m_write_stream.tlast = w_last;
      m_write_stream.tdata = w_data;
      m_write_stream.tstrb = w_strb;
      m_write_stream.tid = '0; // unused;
    end

    // -------------------------------------------------- CONNECTED MODULES ---------------------------------------------------------------------------------

    ////////////////////////////////////////////////////
    // Pre-decode
    ////////////////////////////////////////////////////
    
    // Decode
    logic [7-1:0] opcode_mjr;
    logic [3-1:0] opcode_mnr;
    logic [5-1:0] imm; 
    logic [3-1:0] whole_nf;
    logic vm;
    logic [6-1:0] funct6;
    logic [2-1:0] width_store;

    logic is_vwhole_reg;
    logic is_vwiden;
    logic is_vnarrow;
    logic is_vmask_op;
    logic is_valu;
    logic is_vcfg;
    logic is_vload;
    logic is_vstore;
    logic is_vnagu;

    logic uses_rd;
    logic uses_vd;
    logic uses_vs1;
    logic uses_vs2;
    logic uses_vs3;
    logic uses_vm;

    logic [ADDR_WIDTH-1:0] vm_addr;
    logic [ADDR_WIDTH-1:0] vd_addr;
    logic [ADDR_WIDTH-1:0] vs1_addr;
    logic [ADDR_WIDTH-1:0] vs2_addr;
    logic [ADDR_WIDTH-1:0] vs3_addr;

    logic [DATA_WIDTH-1:0] sca_data_in_1;
    logic [DATA_WIDTH-1:0] sca_data_in_2;

    logic [OFF_BITS-1:0] rd_off_in;
    logic [OFF_BITS-1:0] dest_off_in;

    always_comb begin
      opcode_mjr = insn_in_f[6:0];
      opcode_mnr = insn_in_f[14:12];
      imm        = insn_in_f[19:15];
      whole_nf   = insn_in_f[17:15];
      vm         = insn_in_f[25];
      funct6     = insn_in_f[31:26];
    end

    // FIXME-CARO only helps if avl < single logic lol
    if (ENABLE_64_BIT) begin
      assign width_store = (is_vload | is_vstore) ? opcode_mnr[1:0] : 0;
    end else begin
      assign width_store = (is_vload | is_vstore) ? `MIN(opcode_mnr[1:0], 2'b10) : 0;
    end

    always_comb begin
      vm_addr  = {state_id_f, 5'b0};
      vd_addr  = {state_id_f, insn_in_f[11:7]};
      vs1_addr = {state_id_f, insn_in_f[19:15]};
      vs2_addr = {state_id_f, insn_in_f[24:20]};
      vs3_addr = {state_id_f, insn_in_f[11:7]};
    end

    assign is_valu   = insn_in_f inside {VALU_CFG} & ~(insn_in_f inside {VCFG});
    assign is_vcfg   = insn_in_f inside {VCFG};
    assign is_vload  = insn_in_f inside {VLOAD};
    assign is_vstore = insn_in_f inside {VSTORE};

    if (WHOLE_REG_ENABLE) begin
      assign is_vwhole_reg = insn_in_f inside {VL_1_RE_8_V, VL_2_RE_16_V, VL_4_RE_32_V, VL_8_RE_64_V,
                                              VS_1_R_V, VS_2_R_V, VS_4_R_V, VS_8_R_V,
                                              VMV_1_R_V, VMV_1_R_V, VMV_2_R_V, VMV_4_R_V, VMV_8_R_V};
    end else begin
      assign is_vwhole_reg = 1'b0;
    end

    if (WIDEN_ADD_ENABLE | WIDEN_MUL_ENABLE) begin
      assign is_vwiden = insn_in_f inside {VWADDU_VV, VWADDU_VX, VWADD_VV, VWADD_VX, 
                                           VWSUBU_VV, VWSUBU_VX, VWSUB_VV, VWSUB_VX,
                                           VWMUL_VV, VWMUL_VX, VWMULSU_VV, VWMULSU_VX};
    end else begin
      assign is_vwiden = 1'b0;
    end

    if (NARROW_ENABLE) begin
      assign is_vnarrow = insn_in_f inside {VNSRL_VV, VNSRL_VX, VNSRL_VI};
    end else begin
      assign is_vnarrow = 1'b0;
    end

    if (MASK_ENABLE_EXT) begin
      assign is_vmask_op = insn_in_f inside {VMANDNOT_MM, VMAND_MM, VMOR_MM, VMXOR_MM, VMORNOT_MM, VMNAND_MM, VMNOR_MM, VMXNOR_MM, VCPOP_M, VFIRST_M, VSM_V};
    end else if (MASK_ENABLE) begin
      assign is_vmask_op = insn_in_f inside {VMANDNOT_MM, VMAND_MM, VMOR_MM, VMXOR_MM, VMORNOT_MM, VMNAND_MM, VMNOR_MM, VMXNOR_MM};
    end else begin
      assign is_vmask_op = 'b0;
    end

    assign is_vnagu = insn_in_f inside {VMV_VI, VMV_VX, VMV_SX, VMV_XS, VID_V, VCPOP_M, VFIRST_M};

    assign uses_rd  = insn_in_f inside {VCFG} | insn_in_f inside {VMV_XS, VCPOP_M, VFIRST_M};
    assign uses_vd  = insn_in_f inside {VLOAD} | (insn_in_f inside {VALU_OPIVV, VALU_OPMVV, VALU_OPIVI, VALU_OPIVX, VALU_OPMVX} & ~(insn_in_f inside {VMV_XS, VCPOP_M, VFIRST_M}));
    assign uses_vs1 = insn_in_f inside {VALU_OPIVV, VALU_OPMVV} & ~(insn_in_f inside {VID_V, VMV_XS, VCPOP_M, VFIRST_M});
    assign uses_vs2 = insn_in_f inside {VALU_OPIVV, VALU_OPMVV, VALU_OPIVI, VALU_OPIVX, VALU_OPMVX} & ~(insn_in_f inside {VID_V, VMV_SX, VMV_VV, VMV_VX, VMV_VI}); // Note: Include indexed mops when layer added
    assign uses_vs3 = insn_in_f inside {VSTORE};
    assign uses_vm  = insn_in_f inside {VALU_CFG, VLOAD, VSTORE} & ~(insn_in_f inside {VCFG}) & ~(insn_in_f[25]);

    always_comb begin
      sca_data_in_2 = (DATA_WIDTH)'(data_in_2_f);

      unique casez (insn_in_f)
        VALU_OPIVI: begin
          unique casez (insn_in_f)
            VSLIDEDOWN_VI,
            VSLIDEUP_VI,
            VSLL_VI,
            VSRA_VI,
            VSRL_VI,
            VNSRL_VI: sca_data_in_1 = (DATA_WIDTH)'(imm); //zimm
            default: sca_data_in_1 = (DATA_WIDTH)'(signed'(imm)); //simm
          endcase
        end

        default: sca_data_in_1 = (DATA_WIDTH)'(data_in_1_f);
      endcase
    end

    if (SLIDE_N_ENABLE) begin
      // read later offsets for slide down 
      always_comb begin
        unique casez (insn_in_f)
          VSLIDEDOWN_VI,
          VSLIDEDOWN_VX:  rd_off_in = sca_data_in_1 >> (DW_B_BITS - sew[state_id_f]);
          VSLIDE1DOWN_VX: rd_off_in = 'h0;
          default: rd_off_in = 'h0;
        endcase
      end

      assign dest_off_in = alu_resp_off;
    end else begin
      assign rd_off_in   = 'h0;
      assign dest_off_in = 'h0;
    end

    // Issue
    logic [3-1:0] opcode_mnr_d;
    logic [3-1:0] whole_nf_d;
    logic vm_d;

    logic is_vcfg_d;
    logic is_vload_d;
    logic is_vlm_d;
    logic is_vstore_d;
    logic is_vmv_sca_d;
    logic is_vcomp_d;
    logic is_vwiden_d;
    logic is_vnarrow_d;
    logic is_vwhole_reg_mv_d;
    logic is_vnagu_d;

    logic [ADDR_WIDTH-1:0] vd_addr_d;

    always_comb begin
      opcode_mnr_d = insn_in_d[14:12];
      whole_nf_d   = insn_in_d[17:15];
      vm_d         = insn_in_d[25];
    end

    always_comb begin
      vd_addr_d    = {state_id_d, insn_in_d[11:7]};
    end

    assign is_vcfg_d    = insn_in_d inside {VCFG};
    assign is_vload_d   = insn_in_d inside {VLOAD};
    assign is_vlm_d     = insn_in_d inside {VLM_V};
    assign is_vstore_d  = insn_in_d inside {VSTORE};
    assign is_vmv_sca_d = insn_in_d inside {VMV_SX, VMV_XS};
    assign is_vcomp_d   = insn_in_d inside {VMSEQ_VV, VMSEQ_VX, VMSEQ_VI, VMSNE_VV, VMSNE_VX, VMSNE_VI, VMSLE_VV, VMSLE_VX, VMSLE_VI, VMSLEU_VV, VMSLEU_VX, VMSLEU_VI, VMSLT_VV, VMSLT_VX, VMSGT_VX, VMSGT_VI};

    if (WHOLE_REG_ENABLE) begin
      assign is_vwhole_reg_mv_d = insn_in_d inside {VMV_1_R_V, VMV_1_R_V, VMV_2_R_V, VMV_4_R_V, VMV_8_R_V};
    end else begin
      assign is_vwhole_reg_mv_d = 1'b0;
    end

    if (WIDEN_ADD_ENABLE | WIDEN_MUL_ENABLE) begin
      assign is_vwiden_d = insn_in_d inside {VWADDU_VV, VWADDU_VX, VWADD_VV, VWADD_VX, 
                                             VWSUBU_VV, VWSUBU_VX, VWSUB_VV, VWSUB_VX,
                                             VWMUL_VV, VWMUL_VX, VWMULSU_VV, VWMULSU_VX};
    end else begin
      assign is_vwiden_d = 1'b0;
    end

    if (NARROW_ENABLE) begin
      assign is_vnarrow_d = insn_in_d inside {VNSRL_VV, VNSRL_VX, VNSRL_VI};
    end else begin
      assign is_vnarrow_d = 1'b0;
    end

    assign is_vnagu_d = insn_in_d inside {VMV_VI, VMV_VX, VMV_SX, VMV_XS, VID_V, VCPOP_M, VFIRST_M};

    ////////////////////////////////////////////////////
    // Vector address generation units
    ////////////////////////////////////////////////////
    // Checkpoint

    localparam NUM_AGUS = 5;

    typedef enum bit [$clog2(NUM_AGUS)-1:0] {
      VS1 = 0,
      VS2 = 1,
      VS3 = 2,
      VDA = 3,
      VDR = 4
    } agu_port_t;

    logic agu_en [NUM_AGUS];
    logic agu_ack [NUM_AGUS];
    logic agu_widen_in [NUM_AGUS];
    logic [OFF_BITS-1:0] agu_off_in [NUM_AGUS];
    logic [OFF_BITS-1:0] agu_max_off_in [NUM_AGUS];
    logic [ADDR_WIDTH-1:0] agu_addr_in [NUM_AGUS];
    logic [ADDR_WIDTH-1:0] agu_max_reg_in [NUM_AGUS];
    logic [ADDR_WIDTH-1:0] agu_addr_out [NUM_AGUS];
    logic [OFF_BITS-1:0] agu_off_out [NUM_AGUS];
    logic agu_addr_valid [NUM_AGUS];
    logic agu_addr_start [NUM_AGUS];
    logic agu_addr_end [NUM_AGUS];
    logic agu_idle [NUM_AGUS];
    
    for (i = 0; i < NUM_AGUS; ++i) begin
      addr_gen_unit #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .OFF_WIDTH(OFF_BITS),
        .VLEN(VLEN)) 
      vagu_block (
        .clk(clk), 
        .rst(rst), 
        .en(agu_en[i]), 
        .ack(1'b1),
        .widen_in(agu_widen_in[i]), 
        .off_in(agu_off_in[i]), 
        .max_off_in(agu_max_off_in[i]), 
        .addr_in(agu_addr_in[i]), 
        .max_reg_in(agu_max_reg_in[i]),
        .addr_out(agu_addr_out[i]), 
        .off_out(agu_off_out[i]), 
        .addr_valid(agu_addr_valid[i]), 
        .addr_start(agu_addr_start[i]), 
        .addr_end(agu_addr_end[i]), 
        .idle(agu_idle[i]));
    end

    // Note-unused: agu_addr_start[VDA|VDR], agu_addr_end[VDA|VDR]
    always_comb begin
      agu_en[VS1] = (uses_vs1) & ~stall;
      agu_en[VS2] = (uses_vs2 | uses_vm) & ~stall; //Note: Added uses_vm for vid
      agu_en[VS3] = (uses_vs3) & ~stall;
      agu_en[VDA] = en_vd;
      agu_en[VDR] = is_vload & read_attr_f == READ_COMMIT & ~stall;

      agu_widen_in[VS1] = is_vwiden | is_vwiden_d;
      agu_widen_in[VS2] = is_vwiden | is_vwiden_d;
      agu_widen_in[VS3] = 'h0;
      agu_widen_in[VDA] = alu_resp_narrow;
      agu_widen_in[VDR] = 'h0;

      agu_off_in[VS1] = 'h0;
      agu_off_in[VS2] = rd_off_in;
      agu_off_in[VS3] = 'h0;
      agu_off_in[VDA] = dest_off_in;
      agu_off_in[VDR] = 'h0;

      agu_max_off_in[VS1] = avl_max_off_in_rd;
      agu_max_off_in[VS2] = avl_max_off_in_rd;
      agu_max_off_in[VS3] = avl_max_off_s;
      agu_max_off_in[VDA] = avl_max_off_in_wr;
      agu_max_off_in[VDR] = avl_max_off_s;

      agu_addr_in[VS1] = vs1_addr;
      agu_addr_in[VS2] = vs2_addr;
      agu_addr_in[VS3] = vs3_addr;
      agu_addr_in[VDA] = alu_resp_addr;
      agu_addr_in[VDR] = vd_addr;

      agu_max_reg_in[VS1] = avl_max_reg_in_rd;
      agu_max_reg_in[VS2] = avl_max_reg_in_rd;
      agu_max_reg_in[VS3] = avl_max_reg_s;
      agu_max_reg_in[VDA] = avl_max_reg_in_wr;
      agu_max_reg_in[VDR] = avl_max_reg_s;
    end

    ////////////////////////////////////////////////////
    // Vector register files
    ////////////////////////////////////////////////////

    mpram #(
      .MEMD((VLEN/DATA_WIDTH)*2**ADDR_WIDTH), 
      .DATAW(DATA_WIDTH),
      .nRPORTS(3),
      .nWPORTS(2),
      .TYPE("XOR"),
      .BYP("RAW"),
      .IFILE("")) 
    vrf_block ( 
      .clk(clk),
      .WEnb({|vr_in_en_2, 
             |vr_in_en_1}),
      .WAddr({{vr_in_addr_2, vr_in_off_2}, 
              {vr_in_addr_1, vr_in_off_1}}),
      .WData({vr_in_data_2, 
              vr_in_data_1}),
      .WBe({vr_in_en_2,
            vr_in_en_1}),
      .RAddr({{agu_addr_out[VS3], agu_off_out[VS3]},
              {agu_addr_out[VS2], agu_off_out[VS2]}, 
              {agu_addr_out[VS1], agu_off_out[VS1]}}),
      .RData({vr_rd_data_out_3, 
              vr_rd_data_out_2, 
              vr_rd_data_out_1}));

    if (MASK_ENABLE) begin
      mpram #(
        .MEMD((VLEN/DATA_WIDTH)*2**(ADDR_WIDTH-5)), 
        .DATAW(DATA_WIDTH),
        .nRPORTS(1),
        .nWPORTS(2),
        .TYPE("XOR"),
        .BYP("RAW"),
        .IFILE("")) 
      vmf_block ( 
        .clk(clk),
        .WEnb({|(vr_in_en_2 & {DW_B{vr_in_addr_2[0 +: 5] == 0}}), 
               |(vr_in_en_1 & {DW_B{vr_in_addr_1[0 +: 5] == 0}})}),
        .WAddr({{vr_in_addr_2[5 +: STATE_ID_WIDTH], vr_in_off_2}, 
                {vr_in_addr_1[5 +: STATE_ID_WIDTH], vr_in_off_1}}),
        .WData({vr_in_data_2, 
                vr_in_data_1}),
        .WBe({vr_in_en_2 & {DW_B{vr_in_addr_2[0 +: 5] == 0}}, 
              vr_in_en_1 & {DW_B{vr_in_addr_1[0 +: 5] == 0}}}),
        .RAddr({(~vm_d ? state_id_d : state_id_f), vm_rd_off}), //TODO Test multiple contexts with vmf
        .RData(vm_rd_data_out));

      logic [OFF_BITS-1:0] agu_off_out_vs2_d;

      always_ff @(posedge clk) begin
        agu_off_out_vs2_d <= agu_off_out[VS2];
      end

      extract_mask #(
        .VLEN(VLEN),
        .DATA_WIDTH(DATA_WIDTH), 
        .ADDR_WIDTH(ADDR_WIDTH), 
        .OFF_BITS(OFF_BITS),
        .SEW_WIDTH(2),
        .ENABLE_64_BIT(ENABLE_64_BIT)) 
      extract_mask_block (
        .sew(sew[state_id_d]), 
        .dw_offset(agu_off_out_vs2_d), 
        .mask_en(~vm_d), 
        .mask_data(vm_rd_data_out), 
        .mask_be(mask_be));
    end else begin : no_mask_file
      assign vm_rd_data_out = 'h0;
    end
  
    ////////////////////////////////////////////////////
    // Vector configuration unit
    ////////////////////////////////////////////////////

    vtype_t vtype [NUM_QUEUES];
    logic [VL_BITS-1:0] normal_avl [NUM_QUEUES]; // Application Vector Length (vlen effective)
    logic [VL_BITS-1:0] avl [NUM_QUEUES]; // Application Vector Length (vlen effective)
    logic [VL_BITS-1:0] avl_eff [NUM_QUEUES]; // avl - 1
    logic [2-1:0] sew [NUM_QUEUES]; // we dont do fractional
    logic vill [NUM_QUEUES];

    for (q = 0; q < NUM_QUEUES; ++q) begin
      vcfg #(
        .XLEN(XLEN),
        .VLEN(VLEN),
        .VLMAX(VLMAX),
        .VL_BITS(VL_BITS),
        .ENABLE_64_BIT(ENABLE_64_BIT)) 
      vcfg_block (
        .clk(clk),
        .rst(rst),
        .valid(is_vcfg & state_id_f == q & ~stall),
        .insn(insn_in_f),
        .rf('{data_in_1_f, data_in_2_f}),
        .vl(normal_avl[q]),
        .vtype(vtype[q]));

      always_comb begin
        avl[q] = is_vload & read_attr_f == READ_COMMIT & state_id_f == q & ~stall ? read_avl[q] : 
                                                                                    normal_avl[q];
        avl_eff[q] = avl[q] - 1;
        sew[q] = vtype[q].vsew; 
        vill[q] = vtype[q].vill;
      end
    end

    logic [VL_BITS-1:0] reg_count_avl; // avl - 1

    always_comb begin
      if (is_vwhole_reg) begin
        reg_count_avl = VLEN_B - 1;
      end else if (is_vwiden) begin
        reg_count_avl = 2 * avl_eff[state_id_f]; //Note: Update size???
      end else begin
        reg_count_avl = avl_eff[state_id_f];
      end
    end

    logic [VL_BITS-1:0] read_avl [NUM_QUEUES];
    fifo_interface #(.DATA_WIDTH(VL_BITS)) read_avl_buffers [NUM_QUEUES] ();

    for (q = 0; q < NUM_QUEUES; ++q) begin
      cva5_fifo #(
        .DATA_WIDTH(VL_BITS), 
        .FIFO_DEPTH(MAX_READ_IN_FLIGHT)) 
      read_avl_buffer_block (
        .clk (clk),
        .rst (rst),
        .fifo (read_avl_buffers[q]));

      always_comb begin
        read_avl_buffers[q].potential_pop  = is_vload & read_attr_f == READ_COMMIT & state_id_f == q & ~stall;
        read_avl_buffers[q].potential_push = is_vload & read_attr_f == READ_ISSUE  & state_id_f == q & ~stall;
        read_avl_buffers[q].pop  = read_avl_buffers[q].potential_pop;
        read_avl_buffers[q].push = read_avl_buffers[q].potential_push;
        read_avl_buffers[q].data_in = normal_avl[state_id_f];
        read_avl[q] = read_avl_buffers[q].data_out;
      end
    end

    ////////////////////////////////////////////////////
    // Vector arithmetic and logic unit
    ////////////////////////////////////////////////////

    vALU #(
      .REQ_DATA_WIDTH(DATA_WIDTH), 
      .RESP_DATA_WIDTH(DATA_WIDTH), 
      .REQ_ADDR_WIDTH(ADDR_WIDTH), 
      .REQ_VL_WIDTH(VL_BITS), 
      .AND_OR_XOR_ENABLE(AND_OR_XOR_ENABLE),
      .ADD_SUB_ENABLE(ADD_SUB_ENABLE),
      .MIN_MAX_ENABLE(MIN_MAX_ENABLE),
      .VEC_MOVE_ENABLE(VEC_MOVE_ENABLE),
      .WHOLE_REG_ENABLE(WHOLE_REG_ENABLE), 
      .WIDEN_ADD_ENABLE(WIDEN_ADD_ENABLE),
      .WIDEN_MUL_ENABLE(WIDEN_MUL_ENABLE),
      .NARROW_ENABLE(NARROW_ENABLE),
      .REDUCTION_ENABLE(REDUCTION_ENABLE),
      .MULT_ENABLE(MULT_ENABLE), 
      .MULH_SR_ENABLE(MULH_SR_ENABLE),
      .MULH_SR_32_ENABLE(MULH_SR_32_ENABLE), 
      .MULT64_ENABLE(MULT64_ENABLE),
      .SHIFT_ENABLE(SHIFT_ENABLE),
      .SLIDE_ENABLE(SLIDE_ENABLE), 
      .SLIDE_N_ENABLE(SLIDE_N_ENABLE),
      .MASK_ENABLE(MASK_ENABLE),
      .MASK_ENABLE_EXT(MASK_ENABLE_EXT),
      .FXP_ENABLE(FXP_ENABLE), 
      .SHIFT64_ENABLE(SHIFT64_ENABLE), 
      .ENABLE_64_BIT(ENABLE_64_BIT), 
      .EN_128_MUL(EN_128_MUL))
    valu_block (
      .clk(clk), 
      .rst(rst),
      .req_ready(), 
      .req_valid(alu_req_valid), 
      .req_insn(insn_in_d),
      .req_start(alu_req_start), 
      .req_end(alu_req_end), 
      .req_addr(vd_addr_d), 
      .req_off(alu_req_off), 
      .req_data0(alu_req_data0), 
      .req_data1(alu_req_data1), 
      .req_be(alu_req_be), 
      .req_avl_be(avl_be), 
      .req_vr_idx(alu_req_vr_idx), 
      .req_vxrm(vxrm_in_d), 
      .req_sew(is_vnarrow_d ? (sew[state_id_d] + 2'b1) : (is_vwhole_reg_mv_d ? get_sew(whole_nf_d) : sew[state_id_d])), 
      .req_vl(avl[state_id_d]), 
      .resp_valid(alu_resp_valid), 
      .resp_start(alu_resp_start), 
      .resp_end(alu_resp_end), 
      .resp_addr(alu_resp_addr), 
      .resp_off(alu_resp_off), 
      .resp_data(alu_resp_data), 
      .resp_mask_out(alu_resp_mask), 
      .resp_be(alu_resp_be), 
      .resp_vl(alu_resp_vl), 
      .resp_whole_reg(alu_resp_whole_reg), 
      .resp_sew(alu_resp_sew), 
      .resp_sca_out(alu_resp_sca), 
      .resp_narrow(alu_resp_narrow));

    ////////////////////////////////////////////////////
    // Stages
    ////////////////////////////////////////////////////

    always_ff @(posedge clk) begin
      if (~stall) begin
        insn_in_f     <= req_valid ? req_insn : 'b0;
        insn_valid_f  <= req_valid;
        data_in_1_f   <= req_data0;
        data_in_2_f   <= req_data1;
        if (FXP_ENABLE) begin
          vxrm_in_f <= req_vxrm[1:0];
        end

        if (req_valid) begin
          state_id_f  <= req_state;
          read_attr_f <= req_read_attr;
          track_id_f  <= req_track_id;
        end
      end

      if (rst) begin
        insn_in_f     <= 'b0;
        insn_valid_f  <= 'b0;
        data_in_1_f   <= 'h0;
        data_in_2_f   <= 'h0;
        state_id_f    <= 'h0;
        track_id_f    <= 'h0;
        read_attr_f   <= READ_ISSUE;
        vxrm_in_f     <= 'h0;
      end
    end

    always_ff @(posedge clk) begin
      if (insn_valid_f & ~is_vload & ~is_vstore & ~stall) begin
        insn_in_d <= insn_in_f;
        state_id_d <= state_id_f;
        track_id_d <= track_id_f;
        sca_data_in_1_d <= sca_data_in_1;
        sca_data_in_2_d <= sca_data_in_2;
        vxrm_in_d <= vxrm_in_f;
      end else if (~no_bubble) begin
        insn_in_d <= 'b0;
        state_id_d <= 'b0;
        track_id_d <= 'b0;
        sca_data_in_1_d <= 'b0;
        sca_data_in_2_d <= 'b0;
        vxrm_in_d <= 'b0;
      end

      if (~wait_mem || (r_ready && r_valid && r_last)) begin //FIXME
        insn_in_m <= insn_in_d;
        dest_m <= vd_addr_d;

        opcode_mnr_m <= opcode_mnr_d[1:0];
        if (ENABLE_64_BIT == 0)
          opcode_mnr_m <= `MIN(opcode_mnr_d[1:0], 2'b10);
      end

      if (is_vload_d)
        wait_mem <= 1'b1;
      if (r_ready && r_valid && r_last)
        wait_mem <= 1'b0;

      if (is_vstore_d)
        wait_mem_st <= 1'b1;
      if (b_ready && b_valid)
        wait_mem_st <= 1'b0;

      if (is_vlm_d)
        wait_mem_msk <= 1'b1;
      if (r_ready && r_valid && r_last)
        wait_mem_msk <= 1'b0;
      if (MASK_ENABLE_EXT == 0)
        wait_mem_msk <= 1'b0;

      if (rst) begin
        insn_in_d <= 'b0;
        state_id_d <= 'b0;
        track_id_d <= 'b0;
        sca_data_in_1_d <= 'b0;
        sca_data_in_2_d <= 'b0;
        vxrm_in_d <= 'b0;

        insn_in_m <= 'b0;
        opcode_mnr_m <= 'h0;
        dest_m <= 'h0;

        wait_mem <= 'b0;
        wait_mem_st <= 'b0;
        wait_mem_msk <= 'b0;
      end
    end

    assign no_bubble = hold_reg_group & reg_count != 0;

    ////////////////////////////////////////////////////
    // Retire ports TODO: Fix deadlock
    ////////////////////////////////////////////////////

    localparam NUM_RESP_PORTS = 4;

    fifo_interface #(.DATA_WIDTH(XLEN)) data_buffers [NUM_RESP_PORTS] (); 

    logic data_buffer_valids [NUM_RESP_PORTS];
    logic [XLEN-1:0] data_buffer_data_outs [NUM_RESP_PORTS];

    for (r = 0; r < NUM_RESP_PORTS; ++r) begin
      cva5_fifo #(
        .DATA_WIDTH(XLEN), 
        .FIFO_DEPTH(8)) 
      data_buffer_block (
        .clk (clk),
        .rst (rst),
        .fifo (data_buffers[r]));
      
      //FIXME
      /*
      always_comb begin
        data_buffer_valids[r] = data_buffers[r].valid;
        data_buffer_data_outs[r] = data_buffers[r].data_out;
      end
      */
    end

    always_comb begin
      data_buffer_valids[0] = data_buffers[0].valid;
      data_buffer_valids[1] = data_buffers[1].valid;
      data_buffer_valids[2] = data_buffers[2].valid;
      data_buffer_valids[3] = data_buffers[3].valid;
      data_buffer_data_outs[0] = data_buffers[0].data_out;
      data_buffer_data_outs[1] = data_buffers[1].data_out;
      data_buffer_data_outs[2] = data_buffers[2].data_out;
      data_buffer_data_outs[3] = data_buffers[3].data_out;
    end

    always_comb begin
      data_buffers[ALU].potential_pop  = resp_port_buffer.pop & resp_port_buffer.data_out == ALU;
      data_buffers[ALU].potential_push = alu_resp_valid & alu_resp_end;
      data_buffers[ALU].pop  = data_buffers[ALU].potential_pop;
      data_buffers[ALU].push = data_buffers[ALU].potential_push;
      data_buffers[ALU].data_in = alu_resp_sca ? alu_resp_data[XLEN-1:0] : 'h0; //FIXME

      data_buffers[CFG].potential_pop  = resp_port_buffer.pop & resp_port_buffer.data_out == CFG;
      data_buffers[CFG].potential_push = is_vcfg_d;
      data_buffers[CFG].pop  = data_buffers[CFG].potential_pop;
      data_buffers[CFG].push = data_buffers[CFG].potential_push;
      data_buffers[CFG].data_in = avl[state_id_d];

      data_buffers[LOAD].potential_pop  = resp_port_buffer.pop & resp_port_buffer.data_out == LOAD;
      data_buffers[LOAD].potential_push = fifo_ld_r_en & fifo_ld_r_last;
      data_buffers[LOAD].pop  = data_buffers[LOAD].potential_pop;
      data_buffers[LOAD].push = data_buffers[LOAD].potential_push;
      data_buffers[LOAD].data_in = '0;

      data_buffers[STORE].potential_pop  = resp_port_buffer.pop & resp_port_buffer.data_out == STORE;
      data_buffers[STORE].potential_push = vr_rd_valid_3 & vr_rd_end_3;
      data_buffers[STORE].pop  = data_buffers[STORE].potential_pop;
      data_buffers[STORE].push = data_buffers[STORE].potential_push;
      data_buffers[STORE].data_in = '0;
    end

    fifo_interface #(.DATA_WIDTH($clog2(NUM_RESP_PORTS))) resp_port_buffer (); 

    cva5_fifo #(
      .DATA_WIDTH($clog2(NUM_RESP_PORTS)), 
      .FIFO_DEPTH(32)) 
    resp_port_buffer_block (
      .clk (clk),
      .rst (rst),
      .fifo (resp_port_buffer));

    always_comb begin
      resp_port_buffer.potential_pop  = resp_port_buffer.valid & data_buffer_valids[resp_port_buffer.data_out];
      resp_port_buffer.potential_push = 1'b0;
      resp_port_buffer.data_in = ALU;
      if (insn_valid_f & ~stall) begin
        if (is_valu) begin
          resp_port_buffer.potential_push = 1'b1;
          resp_port_buffer.data_in = ALU;
        end else if (is_vcfg) begin
          resp_port_buffer.potential_push = 1'b1;
          resp_port_buffer.data_in = CFG;
        end else if (is_vstore) begin
          resp_port_buffer.potential_push = 1'b1;
          resp_port_buffer.data_in = STORE;
        end else if (is_vload & read_attr_f == READ_COMMIT) begin
          resp_port_buffer.potential_push = 1'b1;
          resp_port_buffer.data_in = LOAD;
        end
      end 
      resp_port_buffer.pop  = resp_port_buffer.potential_pop;
      resp_port_buffer.push = resp_port_buffer.potential_push;
    end

    always_comb begin
      resp_valid = resp_port_buffer.pop;
      resp_data = data_buffer_data_outs[resp_port_buffer.data_out];
    end

    ////////////////////////////////////////////////////
    // Scoreboard
    ////////////////////////////////////////////////////

    logic scoreboard [NUM_VREGS]; // use this to indicate that vec needs bubble????
    logic sb_set [NUM_VREGS]; 
    logic rd_sb_set [NUM_VREGS];
    logic sb_clr [NUM_VREGS];

    // Hazard COUNT? IS THAT TOO MUCH?
    for (i = 0; i < NUM_VREGS; ++i) begin : haz_logic
      // we shouldn't set the hazard unless we are actually processing a new instruction I think
      assign sb_set[i] = vd_addr == i & uses_vd & ~(is_vload & read_attr_f == READ_COMMIT) & ~stall;
      assign rd_sb_set[i] = vd_addr == i & uses_vd & is_vload & read_attr_f == READ_ISSUE /*& ~stall*/; //Note: ~stall seems to be not necessary
      // testing to see if we can launch early if the next instruction isn't a mask op
      if (MASK_ENABLE_EXT) begin
        assign sb_clr[i] = (dest_m == i & en_ld & ((r_ready & r_valid & r_last) | ~is_vmask_op)) |
                                  (alu_resp_addr == i & alu_resp_valid & (alu_resp_end /*| (alu_resp_start & ~alu_resp_mask)*/));//FIXME Match to non MASK_ENABLE_EXT
      end else begin
          // clear it once only
        assign sb_clr[i] = (read_resp_addr == i & fifo_ld_r_en & fifo_ld_r_last) | (alu_resp_addr == i & alu_resp_valid & (alu_resp_end /*| (alu_resp_start & ~alu_resp_mask) */));
      end
      
      // right now we write to vm multiple times -- this should change to just generate one result and output the whole thing at once
      always_ff @(posedge clk) begin
        if (sb_clr[i]) begin
          scoreboard[i] <= 1'b0;
          read_scoreboard[i] <= 1'b0;
        end

        if (sb_set[i])
          scoreboard[i] <= 1'b1;

        if (rd_sb_set[i])
          read_scoreboard[i] <= 1'b1;

        if (rst) begin
          scoreboard[i] <= 1'b0;
          read_scoreboard[i] <= 1'b0;
        end
      end
    end

    logic [ADDR_WIDTH-1:0] read_resp_addr;
    logic [ADDR_WIDTH-1:0] agu_addr_in_vdr_d;

    always_ff @(posedge clk) begin
      if (agu_en[VDR]) begin
        agu_addr_in_vdr_d <= agu_addr_in[VDR];
      end

      if (rst) begin
        agu_addr_in_vdr_d <= '0;
      end
    end

    assign read_resp_addr = agu_en[VDR] ? agu_addr_in[VDR] : agu_addr_in_vdr_d;
    
    ////////////////////////////////////////////////////
    // Hazard detection
    ////////////////////////////////////////////////////

    // FIXME-CARO? this logic wouldn't work for v1 = v1 + v1
    always_comb begin
      haz_vm   = scoreboard[vm_addr]  & uses_vm;
      haz_vd   = scoreboard[vd_addr]  & uses_vd;
      haz_vs1  = scoreboard[vs1_addr] & uses_vs1;
      haz_vs2  = scoreboard[vs2_addr] & uses_vs2;
      haz_vs3  = scoreboard[vs3_addr] & uses_vs3;
    end

    logic stalls [4];

    always_comb begin
      for (int i = 0; i < 4; ++i) begin
        stalls[i] = 1'b0;
      end
      stall = 1'b0;

      if (insn_valid_f & is_vload & read_attr_f == READ_COMMIT) begin
        stall = ~agu_idle[VDR] | ~agu_idle_vdr_d;
        stalls[0] = stall;
      end else if (insn_valid_f & is_vload & read_attr_f == READ_ISSUE) begin
        stall = haz_vd;
        stalls[1] = stall;
      end else if (insn_valid_f & is_vstore) begin
        stall = ~agu_idle[VS3] | ~agu_idle_vs3_d | haz_vs3 | (is_vstore & writes_in_flight == MAX_WRITE_IN_FLIGHT*NUM_QUEUES);
        stalls[2] = stall;
      end else if (insn_valid_f) begin
        stall = (hold_reg_group & reg_count != 0) | haz_vm | (haz_vd & uses_vm) | haz_vs1 | haz_vs2; 
        stalls[3] = stall;
      end
    end

    assign req_ready = ~stall;

    logic agu_idle_vs3_d;
    logic agu_idle_vdr_d;

    always_ff @(posedge clk) begin
      agu_idle_vs3_d <= agu_idle[VS3];
      agu_idle_vdr_d <= agu_idle[VDR];
      
      if (rst) begin
        agu_idle_vs3_d <= 1'b0;
        agu_idle_vdr_d <= 1'b0;
      end
    end

    // ----------------------------------------- VTYPE CONTROL SIGNALS -------------------------------------------------------------------
    if (WHOLE_REG_ENABLE) begin
      assign whole_reg_ld = insn_in_m inside {VL_1_RE_8_V, VL_2_RE_16_V, VL_4_RE_32_V, VL_8_RE_64_V}; // required for when the data actually comes back //FIXME
    end else begin
      assign whole_reg_ld = 1'b0;
    end

    function logic [OFF_BITS-1:0] get_max_off (logic [VL_BITS-1:0] avl,
                                               logic [VL_BITS-1:0] avl_eff,
                                               logic [2-1:0] sew,
                                               logic is_vmask_op,
                                               logic is_vwhole_reg);
      if (is_vwhole_reg)
        return VLEN_B/DW_B - 1;

      if (is_vmask_op)
        return avl > VLEN/8 ? (VLEN/8)/8 - 1 : avl_eff/8 >> (DW_B_BITS - sew);
      
      return avl > VLEN/8 ? VLEN/8 - 1 : avl_eff >> (DW_B_BITS - sew); //Note: avl>(VLEN/SW)*LMUL to fix max for uneven length across regs
                                                                       //Note: assumption clipping
    endfunction

    assign avl_max_off   = get_max_off(avl[state_id_f], avl_eff[state_id_f], (is_vnarrow ? (sew[state_id_f] + 2'b1) : sew[state_id_f]), is_vmask_op, is_vwhole_reg);
    assign avl_max_off_s = get_max_off(avl[state_id_f], avl_eff[state_id_f], width_store,   is_vmask_op,    is_vwhole_reg);
    assign avl_max_off_w = get_max_off(alu_resp_vl, alu_resp_vl - 1, alu_resp_sew,  alu_resp_mask,  alu_resp_whole_reg);
    assign avl_max_off_l = get_max_off(avl[state_id_f], avl_eff[state_id_f], opcode_mnr_m,  wait_mem_msk,   whole_reg_ld);

    assign avl_max_off_in_rd = is_vstore ? avl_max_off_s : avl_max_off;
    assign avl_max_off_in_wr = avl_max_off_w;
    assign avl_max_off_in_ld = avl_max_off_l;

    function logic [3-1:0] get_max_reg (logic [VL_BITS-1:0] avl_eff,
                                        logic [2-1:0] sew,
                                        logic is_vmask_op,
                                        logic is_vwhole_reg);
      if (is_vwhole_reg)
        return (1 << sew) - 1;

      if (is_vmask_op)
        return 0;

      return avl_eff >> (VLEN_B_BITS - sew);
    endfunction

    assign avl_max_reg   = get_max_reg(avl_eff[state_id_f], (is_vnarrow ? (sew[state_id_f] + 2'b1) : (is_vwhole_reg ? get_sew(whole_nf) : sew[state_id_f])), is_vmask_op, is_vwhole_reg);
    assign avl_max_reg_s = get_max_reg(avl_eff[state_id_f], width_store,   is_vmask_op,    is_vwhole_reg);
    assign avl_max_reg_w = get_max_reg(alu_resp_vl - 1, alu_resp_sew,  alu_resp_mask,  alu_resp_whole_reg);
    assign avl_max_reg_l = get_max_reg(avl_eff[state_id_f], opcode_mnr_m,  wait_mem_msk,   whole_reg_ld);

    assign avl_max_reg_in_rd = is_vstore ? avl_max_reg_s : avl_max_reg;
    assign avl_max_reg_in_wr = avl_max_reg_w;
    assign avl_max_reg_in_ld = avl_max_reg_l;

    // ---------------------------------------- ALU CONTROL --------------------------------------------------------------------------

    // hold values steady while waiting for multiple register groupings
    //FIXME: Loads and fifo_ld_empty
    always_comb begin
      if (reg_count == 0) begin
        hold_reg_group = /*is_vstore | (is_vload & read_attr_f == READ_COMMIT) | */ is_valu; //Note: MASK_ENABLE for is_alu? //FIXME-JO
      end else begin
        hold_reg_group = 1'b1;
      end
    end

    always_comb begin
      if (reg_count == 0) begin
        alu_req_vr_idx_next = 0;
      end else begin
        alu_req_vr_idx_next = alu_req_vr_idx + 1;
      end
    end

    always_ff @(posedge clk) begin
      alu_req_vr_idx <= alu_req_vr_idx_next;

      if (rst)
        alu_req_vr_idx <= 'h0;
    end

    always_ff @(posedge clk) begin
      if (reg_count == 0) begin
        if (hold_reg_group & ~stall) begin
          if (is_vmask_op) begin
            reg_count <= reg_count_avl >> (DW_B_BITS + 3);
            //reg_count_avl * 1 / DATA_WIDTH
          end else if (is_valu | is_vcfg) begin
            if (is_vwhole_reg) begin
              reg_count <= {sca_data_in_1[2:0], (OFF_BITS)'(VLEN_B/DW_B - 1) };
            end else begin
              reg_count <= reg_count_avl >> (DW_B_BITS - (is_vnarrow ? (sew[state_id_f] + 2'b1) : sew[state_id_f]));
            end
            //reg_count_avl * SEW_WIDTH / DATA_WIDTH
          end else begin // FIXME Remove else
            reg_count <= reg_count_avl >> (DW_B_BITS - width_store);
            //reg_count_avl * LS_WIDTH / DATA_WIDTH
          end
        end
      end else begin
        reg_count <= reg_count - 1;
      end

      if (rst) begin
        reg_count <= 'h0;
      end
    end

    // ALU INPUTS
    always_ff @(posedge clk) begin
      alu_req_start <= agu_addr_start[VS1] | agu_addr_start[VS2] | (is_vnagu & reg_count == 0);
      alu_req_end   <= agu_addr_end[VS1]   | agu_addr_end[VS2]   | (is_vnagu_d & reg_count == 1);
      alu_req_off   <= is_vcomp_d ? alu_req_vr_idx_next >> (sew[state_id_d] + 3) : agu_off_out[VS1];

      if (rst) begin
        alu_req_start <= 'h0;
        alu_req_end   <= 'h0;
        alu_req_off   <= 'h0;
      end
    end

    always_comb begin
      unique casez (insn_in_d)
        VALU_OPIVV: alu_req_valid = vr_rd_valid_1 | vr_rd_valid_2;

        VALU_OPMVV: begin
          unique casez (insn_in_d)
            VID_V, VMV_SX, VMV_XS, VCPOP_M, VFIRST_M: alu_req_valid = 1'b1;
            default: alu_req_valid = vr_rd_valid_1 | vr_rd_valid_2;
          endcase
        end
        
        VALU_OPIVI,
        VALU_OPIVX,
        VALU_OPMVX: alu_req_valid = 1'b1;

        default: alu_req_valid = 1'b0;
      endcase
    end

    always_comb begin
      alu_req_data1 = vr_rd_data_out_2;

      unique casez (insn_in_d)
        VALU_OPIVV, VALU_OPMVV: begin //Note: Added OPMVV
          alu_req_data0 = vr_rd_data_out_1;
        end

        VALU_OPIVI, VALU_OPIVX, VALU_OPMVX: begin //Note: Removed VMV_SX and VADC_VX - Added OPIVI
          unique casez (insn_in_d)
            VSLIDEUP_VI, VSLIDEDOWN_VI, 
            VSLIDE1UP_VX, VSLIDE1DOWN_VX, VSLIDEUP_VX, VSLIDEDOWN_VX: alu_req_data0 = sca_data_in_1_d;

            default: begin
              unique case (is_vnarrow_d ? (sew [state_id_d]+ 2'b1) : sew[state_id_d])
                2'b00: alu_req_data0 = {DATA_WIDTH/8{sca_data_in_1_d[8-1:0]}};
                2'b01: alu_req_data0 = {DATA_WIDTH/16{sca_data_in_1_d[16-1:0]}};
                2'b10: alu_req_data0 = {DATA_WIDTH/32{sca_data_in_1_d[32-1:0]}};
                2'b11: alu_req_data0 = ENABLE_64_BIT & DATA_WIDTH >= 64 ? {DATA_WIDTH/64{(64)'(signed'(sca_data_in_1_d[32-1:0]))}}
                                                                        : {(64)'(signed'(sca_data_in_1_d[32-1:0]))};
              endcase
            end
          endcase
        end

        default: begin
          alu_req_data0 = 'h0;
          alu_req_data1 = 'h0;
        end
      endcase
    end

    // --------------------------------------------- AGU INPUT CONTROL ------------------------------------------------------------------

    // used for ALU
    assign en_vd = alu_resp_valid & alu_resp_start & ~alu_resp_sca; // write data

    // used only for STORE-FP. OR with vs1, because there is no situation where vs1 and vs3 exist for the same insn
    assign en_mem_out = agu_addr_valid[VS3];

    // LOAD
    assign en_ld = agu_addr_valid[VDR];

    always_comb begin
      vr_in_en_1   = vr_wr_en;
      vr_in_addr_1 = alu_resp_mask ? alu_resp_addr : agu_addr_out[VDA];
      vr_in_off_1  = alu_resp_mask ? alu_resp_off  : agu_off_out[VDA];
      vr_in_data_1 = vr_wr_data_in;
      vr_in_en_2   = vr_ld_en;
      vr_in_addr_2 = agu_addr_out[VDR];
      vr_in_off_2  = agu_off_out[VDR];
      vr_in_data_2 = vr_ld_data_in;
    end

    // ----------------------------------------------- REGFILE CONTROL --------------------------------------------------------------------
    // FIXME-CARO only read if mask op?

    always_ff @(posedge clk) begin
        // set "active" if we're reading mask or data --
        // all this does is enable the alu so it's fine. 
        vr_rd_valid_1 <= agu_addr_valid[VS1];
        vr_rd_valid_2 <= agu_addr_valid[VS2];
        vr_rd_valid_3 <= agu_addr_valid[VS3];
        vr_rd_start_3 <= agu_addr_start[VS3];
        vr_rd_end_3   <= agu_addr_end[VS3];
    end

    if (MASK_ENABLE) begin
      always_comb begin
        if (~agu_addr_valid[VS2]) begin
          vm_rd_en  = 1'b0;
          vm_rd_off = agu_off_out[VS2];
        end else begin
          vm_rd_en  = (~vm_d | ~vm); //Note: Why vm_rd_en depends on ~agu_addr_valid[VS1]?
          vm_rd_off = (~vm_d | (~vm & ~stall)) ? alu_req_vr_idx_next >> (sew[~vm_d ? state_id_d : state_id_f] + 3) : agu_off_out[VS2];
        end
      end
    end

    // ----------------------------------------------------- MEMORY PORT LOGIC ----------------------------------------------------------------
    // LOAD
    assign vr_ld_data_in = fifo_ld_r_data[DATA_WIDTH-1:0];
    assign vr_ld_ack = 1'b1;
    assign vr_ld_en = {DW_B{en_ld}};

    // --------------------------------------------------- WRITEBACK STAGE LOGIC --------------------------------------------------------------
    assign vr_wr_en = ~agu_addr_valid[VDA] ? 'h0 : alu_resp_be;
    assign vr_wr_data_in = alu_resp_data;

    //FIXME - vm_wr_en can be set by Non-ALU instructions
    if (MASK_ENABLE) begin
      if (MASK_ENABLE_EXT) begin
        assign vm_wr_en = alu_resp_valid & alu_resp_mask & alu_resp_addr == 0 ? alu_resp_be : 'h0; // write mask
      end else begin
        assign vm_wr_en = alu_resp_valid & alu_resp_mask ? alu_resp_be : 'h0; // write mask
      end
    end else begin
      assign vm_wr_en = 'h0;
    end

    // -------------------------------------------------- SIGNAL PROPAGATION LOGIC ------------------------------------------------------------
    // Adding byte enable for ALU
    always_comb begin
      if (is_vmv_sca_d) begin //Note: VCPOP_M? VFIRST_M? 
        if (alu_req_vr_idx == 0) begin
          unique case (sew[state_id_d])
            2'b00: alu_req_be = 'b0000_0001;
            2'b01: alu_req_be = 'b0000_0011;
            2'b10: alu_req_be = 'b0000_1111;
            2'b11: alu_req_be = ENABLE_64_BIT ? 'b1111_1111 : 'b0000_0000;
          endcase
        end else begin
          alu_req_be = 'b0000_0000;
        end
      end else begin // FIXME -- how do we use AVL when it's a variable??
        // Next mask will always come from v0, we really only need to read and write masks for mask manipulation instructions
        if (MASK_ENABLE) begin
          alu_req_be = avl_be & mask_be; // vm=1 is unmasked
        end else begin
          alu_req_be = avl_be;
        end
      end
    end

    generate_be #(
      .VLEN(VLEN),
      .DATA_WIDTH(DATA_WIDTH), 
      .AVL_WIDTH(VL_BITS), 
      .SEW_WIDTH(2), 
      .ENABLE_64_BIT(ENABLE_64_BIT)) 
    generate_be_block (
      .sew(is_vnarrow_d ? (sew[state_id_d] + 2'b1) : (is_vwhole_reg_mv_d ? get_sew(whole_nf_d) : sew[state_id_d])), 
      .avl(avl[state_id_d]), 
      .avl_dw_offset(is_vwiden_d ? 2 * alu_req_vr_idx : alu_req_vr_idx), 
      .avl_be(avl_be));

    
    logic [2-1:0] sew_store;
    logic [VL_BITS-1:0] avl_store;
    logic [DW_B-1:0] avl_be_store;
    logic [VL_BITS-1:0] idx_store;
    logic [ADDR_WIDTH+OFF_BITS-1:0] start_idx_store;

    generate_be #(
      .VLEN(VLEN),
      .DATA_WIDTH(DATA_WIDTH), 
      .AVL_WIDTH(VL_BITS), 
      .SEW_WIDTH(2), 
      .ENABLE_64_BIT(ENABLE_64_BIT)) 
    generate_be_store_block (
      .sew(sew_store), 
      .avl(avl_store), 
      .avl_dw_offset(idx_store), 
      .avl_be(avl_be_store));

    always_ff @(posedge clk) begin
      if (is_vstore & ~stall) begin
        sew_store <= sew[state_id_f];
        avl_store <= avl[state_id_f];
        start_idx_store <= {vs3_addr, (OFF_BITS)'(0)};
      end

      idx_store <= {agu_addr_out[VS3], agu_off_out[VS3]} - (agu_addr_valid[VS3] & agu_addr_start[VS3] ? {vs3_addr, (OFF_BITS)'(0)} : start_idx_store);

      if (rst) begin
        sew_store <= 0;
        avl_store <= 0;
        idx_store <= 0;
      end
    end
    
    always_ff @(posedge clk) begin
      if (is_vcfg_d) begin
        out_avl <= avl[state_id_d];
      end

      if (rst) begin
        out_avl <= 0;
      end
    end
    
    /* AXI READ ADDRESS LOGIC */

    fifo_interface #(.DATA_WIDTH(STATE_ID_WIDTH+TRACK_ID_WIDTH+8+32)) load_req_buffer ();

    cva5_fifo #(
      .DATA_WIDTH(STATE_ID_WIDTH+TRACK_ID_WIDTH+8+32), 
      .FIFO_DEPTH(NUM_QUEUES*MAX_READ_IN_FLIGHT)) 
    load_req_buffer_block (
      .clk (clk),
      .rst (rst),
      .fifo (load_req_buffer));

    always_comb begin
      load_req_buffer.potential_pop  = ar_ready & ar_valid;
      load_req_buffer.potential_push = is_vload & read_attr_f == READ_ISSUE & ~stall; 
                                       //FIXME PERF Can be executed earlier
      load_req_buffer.pop  = load_req_buffer.potential_pop;
      load_req_buffer.push = load_req_buffer.potential_push;
      load_req_buffer.data_in = {{(8)'(state_id_f), track_id_f}, 
                                 (8)'(reg_count_avl >> (DW_B_BITS - width_store)), 
                                 (32)'(data_in_1_f)};
      {ar_id, unaligned_ar_len, unaligned_ar_addr} = load_req_buffer.data_out;
    end

    logic [MEM_ADDR_WIDTH-1:0] unaligned_ar_addr;
    logic [8-1:0] unaligned_ar_len;

    always_comb begin
      ar_valid  = load_req_buffer.valid;
      ar_addr   = (unaligned_ar_addr >> $clog2(DATA_WIDTH/8)) << $clog2(DATA_WIDTH/8);
      ar_len    = unaligned_ar_addr[$clog2(DATA_WIDTH/8)-1:0] == '0 ? unaligned_ar_len : 
                                                                      unaligned_ar_len + 1;
      ar_size   = 3'b011;
    end


    /* AXI READ DATA LOGIC */
    assign r_ready = 1'b1; // TODO fifo_ld_full??

    /* AXI WRITE ADDRESS LOGIC */

    fifo_interface #(.DATA_WIDTH(STATE_ID_WIDTH+TRACK_ID_WIDTH+8+32)) store_req_buffer ();

    cva5_fifo #(
      .DATA_WIDTH(STATE_ID_WIDTH+TRACK_ID_WIDTH+8+32), 
      .FIFO_DEPTH(NUM_QUEUES*MAX_WRITE_IN_FLIGHT)) 
    store_req_buffer_block (
      .clk (clk),
      .rst (rst),
      .fifo (store_req_buffer));

    always_comb begin
      store_req_buffer.potential_pop  = aw_ready & aw_valid;
      store_req_buffer.potential_push = is_vstore & ~stall;
      store_req_buffer.pop  = store_req_buffer.potential_pop;
      store_req_buffer.push = store_req_buffer.potential_push;
      store_req_buffer.data_in = {{(8)'(state_id_f), track_id_f}, 
                                  (8)'(reg_count_avl >> (DW_B_BITS - width_store)), 
                                  (32)'(data_in_1_f)};
      {aw_id, unaligned_aw_len, unaligned_aw_addr} = store_req_buffer.data_out;
    end

    logic [MEM_ADDR_WIDTH-1:0] unaligned_aw_addr;
    logic [8-1:0] unaligned_aw_len;
    always_comb begin
      aw_valid = store_req_buffer.valid;
      aw_addr = (unaligned_aw_addr >> $clog2(DATA_WIDTH/8)) << $clog2(DATA_WIDTH/8);
      aw_len  = unaligned_aw_addr[$clog2(DATA_WIDTH/8)-1:0] == '0 ? unaligned_aw_len : 
                                                                    unaligned_aw_len + 1;
      aw_size  = 3'b011;
    end


    logic [$clog2(MAX_WRITE_IN_FLIGHT*NUM_QUEUES)+1-1:0] writes_in_flight;

    always_ff @ (posedge clk) begin
      writes_in_flight <= writes_in_flight + ($clog2(MAX_READ_IN_FLIGHT*NUM_QUEUES)+1)'(aw_ready & aw_valid) - 
                          ($clog2(MAX_READ_IN_FLIGHT*NUM_QUEUES)+1)'(w_ready & w_valid & w_last);
      if (rst) begin
        writes_in_flight <= 0;
      end
    end

    /* AXI WRITE DATA LOGIC */
    logic [1+DATA_WIDTH/8+DATA_WIDTH-1:0] w_last_data;

    fifo_interface #(.DATA_WIDTH(DATA_WIDTH+DATA_WIDTH/8+1)) store_buffer ();

    cva5_fifo #(
      .DATA_WIDTH(DATA_WIDTH+DATA_WIDTH/8+1), 
      .FIFO_DEPTH(NUM_QUEUES*VLMAX*MAX_WRITE_IN_FLIGHT)) 
    store_buffer_block (
      .clk (clk),
      .rst (rst),
      .fifo (store_buffer));

    always_comb begin
      store_buffer.potential_pop  = w_ready & w_valid;
      store_buffer.potential_push = write_aligner_valid;
      store_buffer.pop  = store_buffer.potential_pop;
      store_buffer.push = store_buffer.potential_push;
      store_buffer.data_in = {(write_aligner_valid & write_aligner_end), 
                               write_aligner_be, write_aligner_data};
      w_last_data = store_buffer.data_out;
    end

    always_comb begin
      w_valid = store_buffer.valid; // FIXME
      w_data  = w_last_data[0 +: DATA_WIDTH];
      w_strb  = w_last_data[DATA_WIDTH +: DATA_WIDTH/8];
      w_last  = w_last_data[$high(w_last_data)];
    end

    logic write_aligner_valid;
    logic write_aligner_start;
    logic write_aligner_end;
    logic [DATA_WIDTH-1:0] write_aligner_data;
    logic [DATA_WIDTH/8-1:0] write_aligner_be;
    logic write_aligner_idle;

    write_burst_aligner #(
      .DATA_WIDTH(DATA_WIDTH)) 
    write_burst_aligner_block (
        .clk(clk),
        .rst(rst),
        .i_valid(vr_rd_valid_3),
        .i_start(vr_rd_start_3),
        .i_end(vr_rd_end_3),
        .i_data(vr_rd_data_out_3),
        .i_be(avl_be_store),
        .i_shamt(write_aligner_shamt),
        .o_valid(write_aligner_valid),
        .o_start(write_aligner_start),
        .o_end(write_aligner_end),
        .o_data(write_aligner_data),
        .o_be(write_aligner_be),
        .o_idle(write_aligner_idle) //Note: Unused?
      );

    logic [$clog2(DATA_WIDTH/8)-1:0] write_aligner_shamt;
    assign write_aligner_shamt = unaligned_aw_addr[$clog2(DATA_WIDTH/8)-1:0];

    /* AXI WRITE RESPONSE LOGIC */
    assign b_ready = 1; 

    /////////////////////////////////////////////////////////////////////////////////
    logic [1+DATA_WIDTH-1:0] fifo_ld_r_datas [NUM_QUEUES];

    logic fifo_ld_r_en;
    logic [1+DATA_WIDTH-1:0] fifo_ld_r_data;
    logic fifo_ld_r_last;

    assign fifo_ld_r_last = fifo_ld_r_data[DATA_WIDTH];

    fifo_interface #(.DATA_WIDTH(1+DATA_WIDTH)) load_buffers [NUM_QUEUES] ();

    for (q = 0; q < NUM_QUEUES; ++q) begin
      cva5_fifo #(
        .DATA_WIDTH(1+DATA_WIDTH), 
        .FIFO_DEPTH(VLMAX*MAX_READ_IN_FLIGHT)) 
      load_buffer_block (
        .clk (clk),
        .rst (rst),
        .fifo (load_buffers[q]));

      always_comb begin
        load_buffers[q].potential_pop  = fifo_ld_r_en && agu_addr_out[VDR][5 +: STATE_ID_WIDTH] == q;
        load_buffers[q].potential_push = read_aligner_valid && r_id[TRACK_ID_WIDTH +: STATE_ID_WIDTH] == q;
        load_buffers[q].pop  = load_buffers[q].potential_pop;
        load_buffers[q].push = load_buffers[q].potential_push;
        load_buffers[q].data_in = {(read_aligner_valid & read_aligner_end), read_aligner_data};
        fifo_ld_r_datas[q] = load_buffers[q].data_out;
      end
    end

    always_comb begin
      fifo_ld_r_en = en_ld;
      fifo_ld_r_data = fifo_ld_r_datas[agu_addr_out[VDR][5 +: STATE_ID_WIDTH]];
    end

    logic read_aligner_valid;
    logic read_aligner_start;
    logic read_aligner_end;
    logic [DATA_WIDTH-1:0] read_aligner_data;
    logic read_aligner_idle;

    read_burst_aligner #(
      .DATA_WIDTH(DATA_WIDTH)) 
    read_burst_aligner_block (
        .clk(clk),
        .rst(rst),
        .i_valid(r_ready & r_valid),
        .i_start(r_ready & r_valid & r_first),
        .i_end(r_ready & r_valid & r_last),
        .i_data(r_data),
        .i_shamt(read_aligner_shamt),
        .o_valid(read_aligner_valid),
        .o_start(read_aligner_start),
        .o_end(read_aligner_end),
        .o_data(read_aligner_data),
        .o_idle(read_aligner_idle) //Note: Unused?
      );

    logic r_first;
    always_ff @(posedge clk) begin
      if (r_ready & r_valid)
        r_first <= r_last;

      if (rst)
        r_first <= 1'b1;
    end

    logic [$clog2(DATA_WIDTH/8)-1:0] read_aligner_shamt;
    always @(posedge clk) begin
      if (ar_ready & ar_valid) 
        read_aligner_shamt <= unaligned_ar_addr[$clog2(DATA_WIDTH/8)-1:0]; //FIXME URGENT

      if (rst)
        read_aligner_shamt <= '0;
    end

    /////////////////////////////////////////////////////////////////////////////////

    mem_packet_t mem_packets [2];
    mem_id_t mem_ids [2];

    always_comb begin
      mem_packets[READ] = '{base_address  : ar_addr,
                            end_address   : ar_addr + (DATA_WIDTH/8)*(ar_len + 1) - 1,
                            size          : ar_size,
                            stride        : 32'b1};
      mem_ids[READ] = ar_id;
    end

    always_comb begin
      mem_packets[WRITE] = '{base_address  : aw_addr,
                             end_address   : aw_addr + (DATA_WIDTH/8)*(aw_len + 1) - 1,
                             size          : aw_size,
                             stride        : 32'b1};
      mem_ids[WRITE] = aw_id; 
    end

    always_comb begin
      ar_ready = m_read_req.ready;
      m_read_req.valid = ar_valid;
      m_read_req.data = mem_packets[READ];
      m_read_req.id = mem_ids[READ];
    end

    always_comb begin
      aw_ready = m_write_req.ready;
      m_write_req.valid = aw_valid;
      m_write_req.data = mem_packets[WRITE];
      m_write_req.id = mem_ids[WRITE];
    end

    ////////////////////////////////////////////////////
    // Performace counters
    ////////////////////////////////////////////////////
    
    typedef enum int unsigned {
      BUBBLE = 0,
      INUSE = 1,
      STALL = 2
    } cnt_t;

    logic [32-1:0] running_cnt;

    always_ff @(posedge clk) begin
      if (insn_in_d == 0) begin
        running_cnt <= running_cnt + 1;
      end else begin
        perf_cnts[INUSE] <= perf_cnts[INUSE] + 1;
        if (perf_cnts[INUSE] != 0)
          perf_cnts[BUBBLE] <= perf_cnts[BUBBLE] + running_cnt;
        running_cnt <= 0;
      end

      for (int i = 0; i < 4; ++i) begin
        if (stalls[i]) begin
          perf_cnts[STALL+i] <= perf_cnts[STALL+i] + 1;
        end
      end

      if (rst) begin
        running_cnt <= 0;
        for (int i = 0; i < NUM_PERF_COUNTERS; ++i) begin
          perf_cnts[i] <= 0;
        end
      end
    end

  ////////////////////////////////////////////////////
  //Assertions

endmodule
