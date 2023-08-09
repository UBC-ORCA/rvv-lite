`define LD_INSN 7'h07
`define ST_INSN 7'h27
`define OP_INSN 7'h57

`define IVV_TYPE 3'h0
`define FVV_TYPE 3'h1
`define MVV_TYPE 3'h2
`define IVI_TYPE 3'h3
`define IVX_TYPE 3'h4
`define FVF_TYPE 3'h5
`define MVX_TYPE 3'h6
`define CFG_TYPE 3'h7

`define MIN(a,b) {(a > b) ? b : a}

`define FIFO_DEPTH_BITS 11 // the max number of packets in a full read is 2048

module rvv_proc_main 
import opcodes::*;
#( 
    parameter VLEN              = 16384, // vector length in bits
    parameter VLEN_B            = VLEN >> 3, // same as VLMAX
    parameter VLEN_B_BITS       = $clog2(VLEN_B),
    parameter XLEN              = 32, // not sure, data width maybe?
    parameter NUM_VEC           = 32, // number of available vector registers
    parameter INSN_WIDTH        = 32, // width of a single instruction
    parameter DATA_WIDTH        = 64,
    parameter DATA_WIDTH_BITS   = $clog2(DATA_WIDTH),
    parameter DW_B              = DATA_WIDTH>>3, // DATA_WIDTH in bytes
    parameter DW_B_BITS         = DATA_WIDTH_BITS-3,
    parameter ADDR_WIDTH        = 5, // 5 bits for 32 vector regs
    parameter MEM_ADDR_WIDTH    = 32, // We need to get this from VexRiscV
    parameter MEM_DATA_WIDTH    = DATA_WIDTH,
    parameter MEM_DW_B          = MEM_DATA_WIDTH>>3,
    parameter VEX_DATA_WIDTH    = 32,
    parameter FIFO_DEPTH_BITS   = 11,
    parameter BYTE              = 8,
    parameter OFF_BITS          = $clog2(VLEN/DATA_WIDTH), // max value is 256 (16384/64)
    parameter ENABLE_64_BIT     = 1,
    parameter AND_OR_XOR_ENABLE = 1,  // a1b
    parameter ADD_SUB_ENABLE    = 1,  // a1b
    parameter MIN_MAX_ENABLE    = 1,  // a1c
    parameter MASK_ENABLE       = 1,  // a1d
    parameter VEC_MOVE_ENABLE   = 1,  // a1e
    parameter WHOLE_REG_ENABLE  = 1,  // a1f
    parameter SLIDE_ENABLE      = 1,  // a1g
    parameter WIDEN_ADD_ENABLE  = 1,  // a2
    parameter REDUCTION_ENABLE  = 1,  // a3
    parameter MULT_ENABLE       = 1,  // a4a
    parameter SHIFT_ENABLE      = 1,  // a4a   
    parameter MULH_SR_ENABLE    = 1,  // a4b
    parameter MULH_SR_32_ENABLE = 1,  // a4c
    parameter WIDEN_MUL_ENABLE  = 1,  // a4d
    parameter NARROW_ENABLE     = 1,  // a4d
    parameter SLIDE_N_ENABLE    = 1,  // a5
    parameter MULT64_ENABLE     = 0,  // a6
    parameter SHIFT64_ENABLE    = 0,  // a6
    parameter FXP_ENABLE        = 1,  // a7
    parameter MASK_ENABLE_EXT   = 1,  // b1
    parameter EN_128_MUL        = 0
) (
    input  logic clk,
    input  logic rst_n,
    input  logic [INSN_WIDTH-1:0] insn_in, // make this a queue possibly
    input  logic insn_valid,
    input  logic [2:0] vxrm_in,
    input  logic [VEX_DATA_WIDTH-1:0] vexrv_data_in_1, // memory address from load/store command
    input  logic [VEX_DATA_WIDTH-1:0] vexrv_data_in_2,
    output logic proc_rdy,
    output logic [VEX_DATA_WIDTH-1:0] vexrv_data_out,
    output logic vexrv_valid_out,

    // INVALIDATION
    input  logic inv_ack,
    output logic inv_valid,
    output logic [MEM_ADDR_WIDTH-1:0] inv_addr,

    /* AXI */
    // Read address channel
    output logic [1:0] ar_burst,
    output logic [2:0] ar_size,
    output logic [3:0] ar_cache,
    output logic [5:0] ar_id,
    output logic [7:0] ar_len,
    output logic [MEM_ADDR_WIDTH-1:0] ar_addr,
    output logic ar_valid,
    input  logic ar_ready,

    // Read data channel
    input  logic [5:0] r_id,
    input  logic [DATA_WIDTH-1:0] r_data,
    input  logic [1:0] r_resp,
    input  logic r_last,
    input  logic r_valid,
    output logic r_ready,

    // Write address channel
    output logic [1:0] aw_burst,
    output logic [2:0] aw_size,
    output logic [3:0] aw_cache,
    output logic [5:0] aw_id,
    output logic [7:0] aw_len,
    output logic [MEM_ADDR_WIDTH-1:0] aw_addr,
    output logic aw_valid,
    input  logic aw_ready,

    // Write data channel
    input  logic w_ready,
    output logic w_valid,
    output logic [DATA_WIDTH-1:0] w_data,
    output logic [(DATA_WIDTH/8)-1:0] w_strb, //FIXME
    output logic w_last,

    // Write response channel
    input  logic b_valid,
    input  logic [1:0] b_resp,
    input  logic [5:0] b_id,
    output logic b_ready
);
    logic vr_rd_en_1;
    logic vr_rd_en_2;
    logic vr_rd_valid_1;
    logic vr_rd_valid_2;
    logic [DW_B-1:0] vr_wr_en;
    logic [DW_B-1:0] vr_ld_en;
    logic [DW_B-1:0] vr_in_en;
    
    logic [DW_B-1:0] mask_be;

    logic vm_rd_en;
    logic [DW_B-1:0] vm_wr_en;

    logic [ADDR_WIDTH-1:0] vr_rd_addr_1;
    logic [ADDR_WIDTH-1:0] vr_rd_addr_2;
    logic [ADDR_WIDTH-1:0] vr_wr_addr;
    logic [ADDR_WIDTH-1:0] vr_ld_addr;
    logic [ADDR_WIDTH-1:0] vr_in_addr;

    logic [OFF_BITS-1:0] vr_rd_off_1;
    logic [OFF_BITS-1:0] vr_rd_off_2;
    logic [OFF_BITS-1:0] vr_wr_off;
    logic [OFF_BITS-1:0] vr_ld_off;
    logic [OFF_BITS-1:0] vr_in_off;

    logic [OFF_BITS-1:0] vm_in_off;
    logic [OFF_BITS-1:0] vm_rd_off;
    logic [ADDR_WIDTH-1:0] vm_in_addr;
    logic [ADDR_WIDTH-1:0] vm_rd_addr;

    logic [DATA_WIDTH-1:0] vr_wr_data_in;
    logic [DATA_WIDTH-1:0] vr_rd_data_out_1;
    logic [DATA_WIDTH-1:0] vr_rd_data_out_2;
    logic [DATA_WIDTH-1:0] vr_ld_data_in;
    logic [DATA_WIDTH-1:0] vr_in_data;

    logic [DATA_WIDTH-1:0] vm_rd_data_out;

    logic [INSN_WIDTH-1:0] insn_in_f;
    logic insn_valid_f;
    logic [VEX_DATA_WIDTH-1:0] data_in_1_f;
    logic [VEX_DATA_WIDTH-1:0] data_in_2_f;
    logic [1:0] vxrm_in_f;

    logic stall;

    logic en_mem_out;
    logic [MEM_ADDR_WIDTH-1:0] mem_addr_in_d;

    // insn decomposition -- mostly general
    logic [6:0] opcode_mjr;
    logic [2:0] opcode_mnr;
    logic [4:0] dest; // rd, vd, or vs3 -- TODO make better name lol
    logic [4:0] src_1; // rs1, vs1, or imm/uimm
    logic [4:0] src_2; // rs2, vs2, or imm -- for mem could be lumop, sumop

    // vmem
    logic [2:0] width;
    logic [1:0] mop;
    logic mew;
    logic [2:0] nf;

    // vcfg
    logic [10:0] vtype_11;
    logic [9:0] vtype_10;
    logic [1:0] cfg_type;
    logic cfg_en;

    // valu
    logic vm;
    logic [5:0] funct6;

    logic [DATA_WIDTH-1:0] sca_data_in_1;
    logic [DATA_WIDTH-1:0] sca_data_in_2;

    logic is_vmask_op;
    logic is_valu;
    logic is_vcfg;
    logic is_vload;
    logic is_vstore;
    logic uses_rd;
    logic uses_vd;
    logic uses_vs1;
    logic uses_vs2;
    logic uses_vs3;
    logic uses_vm;

    logic en_vd;
    logic en_ld;

    // value propagation signals
    logic [INSN_WIDTH-1:0] insn_in_d;
    logic [6:0] opcode_mjr_d;
    logic [2:0] opcode_mnr_d;
    logic [4:0] dest_d; // rd, vd, or vs3 -- TODO make better name lol
    logic [5:0] funct6_d;
    logic vm_d;
    logic [DATA_WIDTH-1:0] sca_data_in_1_d;
    logic [DATA_WIDTH-1:0] sca_data_in_2_d;
    logic [1:0] vxrm_in_d;

    logic [INSN_WIDTH-1:0] insn_in_m;
    logic [1:0] opcode_mnr_m;
    logic [4:0] dest_m; // rd, vd, or vs3 -- TODO make better name lol
    logic [1:0] width_store;

    logic out_ack_e;
    logic [VEX_DATA_WIDTH-1:0] out_data_e;
    logic out_ack_m;

    // CONFIG VALUES -- config unit flops them, these are just connector logics
    logic [VLEN_B_BITS+1-1:0] avl; // Application Vector Length (vlen effective)
    logic [VLEN_B_BITS+1-1:0] avl_eff; // avl - 1
    logic [VLEN_B_BITS+1-1:0] reg_count_avl; // avl - 1
    logic new_vl;

    // VTYPE values
    logic [1:0] sew; // we dont do fractional
    logic [XLEN-1:0] vtype;
    logic vill;

    logic [XLEN-1:0] vtype_nxt;
    logic [1:0] avl_set;
    logic [VLEN_B_BITS+1-1:0] reg_count;

    logic agu_idle_rd_1;
    logic agu_idle_rd_2;
    logic agu_idle_wr;
    logic agu_idle_ld;

    logic alu_req_valid;
    logic [1:0] alu_req_vxrm;
    
    logic [DATA_WIDTH-1:0] alu_req_data0;
    logic [DATA_WIDTH-1:0] alu_req_data1;
    logic [DATA_WIDTH-1:0] alu_resp_data;

    logic [ADDR_WIDTH-1:0] alu_resp_addr;
    logic [OFF_BITS-1:0] alu_req_off;
    logic [OFF_BITS-1:0] alu_resp_off;
    logic alu_resp_valid;
    logic [VLEN_B_BITS+1-1:0] alu_resp_vl;
    logic alu_resp_mask;
    logic alu_resp_sca;
    logic [DW_B-1:0] alu_req_be;
    logic [DW_B-1:0] alu_resp_be;
    logic [VLEN_B_BITS+1-1:0] alu_req_vr_idx; // MAX VALUE IS 2047
    logic [VLEN_B_BITS+1-1:0] alu_req_vr_idx_next; // MAX VALUE IS 2047
    logic alu_resp_whole_reg; // whole register insn

    logic hold_reg_group;
    logic vec_haz [NUM_VEC]; // use this to indicate that vec needs bubble????
    logic vec_haz_set [NUM_VEC]; // use this to indicate that vec needs bubble????
    logic vec_haz_clr [NUM_VEC]; // use this to indicate that vec needs bubble????
    logic no_bubble;

    logic wait_mem;
    logic wait_mem_st;
    logic wait_mem_msk;
    logic wait_cfg;

    // Detect hazards for operands
    logic haz_vd;
    logic haz_vs1;
    logic haz_vs2;
    logic haz_vs3;

    logic [5-1:0] vd_addr;
    logic [5-1:0] vs1_addr;
    logic [5-1:0] vs2_addr;
    logic [5-1:0] vs3_addr;


    logic agu_addr_start_rd_1, agu_addr_start_rd_2, agu_addr_start_wr;
    logic agu_addr_end_rd_1, agu_addr_end_rd_2, agu_addr_end_wr;

    logic alu_req_start, alu_req_end;
    logic alu_resp_start, alu_resp_end;
    logic [1:0] alu_resp_sew;

    logic [OFF_BITS-1:0] avl_max_off;
    logic [OFF_BITS-1:0] avl_max_off_m;
    logic [OFF_BITS-1:0] avl_max_off_l;
    logic [OFF_BITS-1:0] avl_max_off_l_m;
    logic [OFF_BITS-1:0] avl_max_off_s;
    logic [OFF_BITS-1:0] avl_max_off_s_m;
    logic [OFF_BITS-1:0] avl_max_off_w;
    logic [OFF_BITS-1:0] avl_max_off_w_m;
    logic [OFF_BITS-1:0] avl_max_off_in_rd;

    logic [2:0] avl_max_reg;
    logic [2:0] avl_max_reg_w;
    logic [2:0] avl_max_reg_l;
    logic [2:0] avl_max_reg_s;

    logic [OFF_BITS-1:0] avl_max_off_in_ld;
    logic [OFF_BITS-1:0] avl_max_off_in_wr;

    logic whole_reg_rd;
    logic whole_reg_ld;

    logic [DW_B-1:0] avl_be;
    logic [DW_B_BITS-1:0] mask_off [0:3];

    logic widen_en;
    logic widen_en_d;
    logic alu_resp_narrow;

    logic [OFF_BITS-1:0] rd_off_in, dest_off_in;

    genvar i,j;
    integer k;

    logic [DATA_WIDTH-1:0] mem_port_data_in;
    logic mem_port_valid_in;
    logic mem_port_done_ld;
    logic mem_port_done_st;
    logic [MEM_DATA_WIDTH-1:0] mem_port_data_out;
    logic [MEM_ADDR_WIDTH-1:0] mem_port_addr_out;
    logic mem_port_req_out; // signal dicating request vs write
    logic mem_port_valid_out;
    logic [MEM_DW_B-1:0] mem_port_be_out;
    logic mem_port_start_out;
    logic mem_port_ready_out;

    logic vr_ld_ack;

    // -------------------------------------------------- CONNECTED MODULES ---------------------------------------------------------------------------------

    insn_decoder #(
      .INSN_WIDTH(INSN_WIDTH)) 
    insn_decoder_block (
      .insn_in(insn_in_f), 
      .opcode_mjr(opcode_mjr), 
      .opcode_mnr(opcode_mnr), 
      .dest(dest), 
      .src_1(src_1), 
      .src_2(src_2), 
      .width(width), 
      .mop(mop), 
      .mew(mew), 
      .nf(nf), 
      .vtype_11(vtype_11), 
      .vtype_10(vtype_10), 
      .vm(vm), 
      .funct6(funct6), 
      .cfg_type(cfg_type));

    addr_gen_unit #(
      .ADDR_WIDTH(ADDR_WIDTH),
      .DATA_WIDTH(DATA_WIDTH),
      .VLEN(VLEN)) 
    agu_vs1_block (
      .clk(clk), 
      .rst_n(rst_n), 
      .en((uses_vs1 | uses_vs3) & ~stall), 
      .sew(is_vmask_op ? 'h0 : (uses_vs1 ? sew : width_store)), 
      .whole_reg(whole_reg_rd),
      .addr_in(uses_vs1 ? vs1_addr : vs3_addr),
      .addr_out(vr_rd_addr_1),
      .max_reg_in(is_vmask_op ? 'h0 : (uses_vs1 ? avl_max_reg : avl_max_reg_s)), 
      .max_off_in(avl_max_off_in_rd), 
      .off_in('h0), 
      .off_out(vr_rd_off_1), 
      .idle(agu_idle_rd_1), 
      .addr_start(agu_addr_start_rd_1), 
      .addr_end(agu_addr_end_rd_1), 
      .widen(widen_en | widen_en_d), 
      .ack(1));

    addr_gen_unit #(
      .ADDR_WIDTH(ADDR_WIDTH),
      .DATA_WIDTH(DATA_WIDTH),
      .VLEN(VLEN)) 
    agu_vs2_block (
      .clk(clk), 
      .rst_n(rst_n), 
      .en((uses_vs2 | uses_vm) & ~stall),  //Note: Added uses_vm for vid
      .sew(is_vmask_op ? 'h0 : sew), 
      .whole_reg(whole_reg_rd),
      .addr_in(vs2_addr), 
      .addr_out(vr_rd_addr_2),
      .max_reg_in(is_vmask_op ? 'h0 : avl_max_reg), 
      .max_off_in(avl_max_off_in_rd), 
      .off_in(rd_off_in), 
      .off_out(vr_rd_off_2), 
      .idle(agu_idle_rd_2), 
      .addr_start(agu_addr_start_rd_2), 
      .addr_end(agu_addr_end_rd_2), 
      .widen(widen_en | widen_en_d), 
      .ack(1));

    addr_gen_unit #(
      .ADDR_WIDTH(ADDR_WIDTH),
      .DATA_WIDTH(DATA_WIDTH),
      .VLEN(VLEN)) 
    agu_vd_alu_block (
      .clk(clk), 
      .rst_n(rst_n), 
      .en(en_vd), 
      .sew(alu_resp_sew), 
      .whole_reg(alu_resp_whole_reg),
      .addr_in(alu_resp_addr), 
      .addr_out(vr_wr_addr), 
      .max_reg_in(alu_resp_mask ? 'h0 : avl_max_reg_w),
      .max_off_in(avl_max_off_in_wr), 
      .off_in(dest_off_in), 
      .off_out(vr_wr_off), 
      .idle(agu_idle_wr), 
      .widen(alu_resp_narrow), 
      .addr_start(), 
      .addr_end(), 
      .ack(1));
    
    addr_gen_unit #(
      .ADDR_WIDTH(ADDR_WIDTH),
      .DATA_WIDTH(DATA_WIDTH),
      .VLEN(VLEN)) 
    agu_vd_load_block (
      .clk(clk), 
      .rst_n(rst_n), 
      .en(wait_mem & r_valid), 
      .sew(opcode_mnr_m), 
      .whole_reg(whole_reg_ld),
      .addr_in(dest_m), 
      .addr_out(vr_ld_addr), 
      .max_reg_in(wait_mem_msk ? 'h0 : avl_max_reg_l),
      .max_off_in(avl_max_off_in_ld), 
      .off_in('h0), 
      .off_out(vr_ld_off), 
      .idle(agu_idle_ld), 
      .widen(1'b0), 
      .addr_start(), 
      .addr_end(), 
      .ack(vr_ld_ack));

    // TODO-CARO: make this a proper ("true dual-port ram")
    vec_regfile #(
      .VLEN(VLEN), 
      .DATA_WIDTH(DATA_WIDTH), 
      .ADDR_WIDTH(ADDR_WIDTH), 
      .OFF_BITS(OFF_BITS)) 
    vrf_block (
      .clk(clk),
      .rst_n(rst_n), 
      .rd_en_1(vr_rd_en_1), 
      .rd_en_2(vr_rd_en_2), 
      .rd_addr_1(vr_rd_addr_1), 
      .rd_addr_2(vr_rd_addr_2), 
      .rd_off_1(vr_rd_off_1), 
      .rd_off_2(vr_rd_off_2), 
      .rd_data_out_1(vr_rd_data_out_1), 
      .rd_data_out_2(vr_rd_data_out_2), 
      .wr_en(vr_in_en),     
      .wr_addr(vr_in_addr), 
      .wr_off(vr_in_off),   
      .wr_data_in(vr_in_data));

    if (MASK_ENABLE) begin
      // only vm0
      logic [DATA_WIDTH-1:0] mask_data [VLEN/DATA_WIDTH-1:0]; //Note: VLMAX=VLEN/8 instead?
      logic [OFF_BITS-1:0] vr_rd_off_2_d;

      always_ff @(posedge clk) begin
        for (int i = 0; i < DATA_WIDTH/8; i++) begin
          if (vr_in_en[i] && vr_in_addr == 0) begin
            mask_data[vr_in_off][i*8 +: 8] <= vr_in_data[i*8 +: 8];
          end
        end

        if (vm_rd_en) begin                       // Note: Detach from agu_idle_src2 - uses_vm ?
          vm_rd_data_out <= mask_data[vm_rd_off]; // timed with regfile
        end
      end

      always_ff @(posedge clk) begin
        vr_rd_off_2_d <= vr_rd_off_2;
      end

      extract_mask #(
        .VLEN(VLEN),
        .DATA_WIDTH(DATA_WIDTH), 
        .OFF_BITS(OFF_BITS),
        .SEW_WIDTH(2),
        .ENABLE_64_BIT(ENABLE_64_BIT)) 
      extract_mask_block (
        .sew(sew), 
        .dw_offset(vr_rd_off_2_d), 
        .mask_en(~vm_d), 
        .mask_data(vm_rd_data_out), 
        .mask_be(mask_be));
    end else begin : no_mask_file
      assign vm_rd_data_out = 'h0;
    end
  
    cfg_unit #(
      .XLEN(XLEN), 
      .VLEN(VLEN), 
      .ENABLE_64_BIT(ENABLE_64_BIT)) 
    cfg_unit_block (
      .clk(clk), 
      .en(cfg_en), 
      .vtype_nxt(vtype_nxt), 
      .cfg_type(cfg_type), 
      .avl_set(avl_set), 
      .avl_new(~(&cfg_type) ? data_in_1_f : src_1), 
      .avl(avl), 
      .sew(sew), 
      .vill(vill), 
      .new_vl(new_vl));

    vALU #(
      .REQ_DATA_WIDTH(DATA_WIDTH), 
      .RESP_DATA_WIDTH(DATA_WIDTH), 
      .REQ_ADDR_WIDTH(ADDR_WIDTH), 
      .REQ_VL_WIDTH(VLEN_B_BITS+1), 
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
      .rst(~rst_n),
      .req_insn(insn_in_d),
      .req_slide1(alu_req_slide1),
      .req_valid(alu_req_valid), 
      .req_start(alu_req_start), 
      .req_end(alu_req_end), 
      .req_addr(dest_d), 
      .req_off(alu_req_off), 
      .req_data0(alu_req_data0), 
      .req_data1(alu_req_data1), 
      .req_mask(vm_d), 
      .req_be(alu_req_be), 
      .req_vr_idx(alu_req_vr_idx), 
      .req_vxrm(vxrm_in_d), 
      .req_op_mnr(opcode_mnr_d), 
      .req_func_id(funct6_d), 
      .req_sew(sew), 
      .req_vl(avl), 
      .req_ready(), 
      .resp_valid(alu_resp_valid), 
      .resp_start(alu_resp_start), 
      .resp_end(alu_resp_end), 
      .resp_addr(alu_resp_addr), 
      .resp_off(alu_resp_off), 
      .resp_data(alu_resp_data), 
      .resp_mask_out(alu_resp_mask), 
      .resp_be(alu_resp_be), 
      .req_vl_out(alu_resp_vl), 
      .resp_whole_reg(alu_resp_whole_reg), 
      .resp_sew(alu_resp_sew), 
      .resp_sca_out(alu_resp_sca), 
      .resp_narrow(alu_resp_narrow));

    // -------------------------------------------------- FETCH AND HAZARD DETECTION -----------------------------------------------------------------------
    always_ff @(posedge clk) begin
      if (~stall) begin
        insn_in_f     <= insn_valid ? insn_in : 'b0;
        insn_valid_f  <= insn_valid;
        data_in_1_f   <= vexrv_data_in_1;
        data_in_2_f   <= vexrv_data_in_2;
      end

      if (~rst_n) begin
        insn_in_f     <= 'b0;
        insn_valid_f  <= 'b0;
        data_in_1_f   <= 'h0;
        data_in_2_f   <= 'h0;
      end
    end

    if (FXP_ENABLE) begin
      always_ff @(posedge clk) begin
        if (~stall)
          vxrm_in_f <= vxrm_in[1:0];
      end
    end else begin
      assign vxrm_in_f = 0;
    end

    assign vd_addr  = insn_in_f[11:7];
    assign vs1_addr = insn_in_f[19:15];
    assign vs2_addr = insn_in_f[24:20];
    assign vs3_addr = insn_in_f[11:7];

    // Hazard COUNT? IS THAT TOO MUCH?
    for (i = 0; i < NUM_VEC; i++) begin : haz_logic
      // we shouldn't set the hazard unless we are actually processing a new instruction I think
      assign vec_haz_set[i] = vd_addr == i & uses_vd & ~stall;
      // testing to see if we can launch early if the next instruction isn't a mask op
      if (MASK_ENABLE_EXT) begin
        assign vec_haz_clr[i] = (dest_m == i & en_ld & ((r_last & r_valid) | ~is_vmask_op)) |
                                  (alu_resp_addr == i & alu_resp_valid & (alu_resp_end | (alu_resp_start & ~alu_resp_mask)));
      end else begin
          // clear it once only
        assign vec_haz_clr[i] = (dest_m == i & en_ld) | (alu_resp_addr == i & alu_resp_valid & (alu_resp_end | (alu_resp_start & ~alu_resp_mask)));
      end
      
      // right now we write to vm multiple times -- this should change to just generate one result and output the whole thing at once
      always_ff @(posedge clk) begin
        if (vec_haz_clr[i])
          vec_haz[i] <= 1'b0;
        if (vec_haz_set[i])
          vec_haz[i] <= 1'b1;

        if (~rst_n)
          vec_haz[i] <= 1'b0;
      end
    end
  
    // FIXME-CARO? this logic wouldn't work for v1 = v1 + v1
    assign haz_vd   = vec_haz[vd_addr]  & uses_vd;
    assign haz_vs1  = vec_haz[vs1_addr] & uses_vs1;
    assign haz_vs2  = vec_haz[vs2_addr] & uses_vs2;
    assign haz_vs3  = vec_haz[vs3_addr] & uses_vs3;
    //Note: has_vm????

    assign wait_cfg = insn_in_d inside {VCFG};

    // Load doesn't really ever have hazards, since it just writes to a logic and that should be in order! Right?
    // WRONG -- CONSIDER CASE WHERE insn in the ALU path has the same dest addr. We *should* preserve write order there.

    // Just stall for WAW hazards for now
    // wait_mem included because the memory port can only handle one transaction at a time
    assign stall = (hold_reg_group & reg_count != 0) | haz_vd | haz_vs1 | haz_vs2 | haz_vs3 | wait_mem | wait_mem_st | wait_cfg;

    assign proc_rdy = ~stall;
    // ----------------------------------------- VTYPE CONTROL SIGNALS -------------------------------------------------------------------

    assign vtype_nxt = cfg_type[1] ? vtype_10 : vtype_11;
    assign cfg_en = insn_in_f inside {VCFG} & ~stall;
    assign avl_set = {(dest == 'h0),(src_1 == 'h0)}; // determines if rd and rs1 are non-zero, as AVL setting depends on this

    assign avl_eff = avl - 1;

    if (WIDEN_ADD_ENABLE | WIDEN_MUL_ENABLE) begin
      assign widen_en = insn_in_f inside {VWADDU_VV, VWADDU_VX, VWADD_VV, VWADD_VX, 
                                          VWSUBU_VV, VWSUBU_VX, VWSUB_VV, VWSUB_VX,
                                          VWMUL_VV, VWMUL_VX, VWMULSU_VV, VWMULSU_VX};
    end else begin
      assign widen_en = 1'b0;
    end

    if (WHOLE_REG_ENABLE) begin
      assign whole_reg_rd = insn_in_f inside {VL_1_RE_8_V, VL_2_RE_16_V, VL_4_RE_32_V, VL_8_RE_64_V,
                                              VS_1_R_V, VS_2_R_V, VS_4_R_V, VS_8_R_V,
                                              VMV_1_R_V, VMV_1_R_V, VMV_2_R_V, VMV_4_R_V, VMV_8_R_V};
      assign whole_reg_ld = insn_in_m inside {VL_1_RE_8_V, VL_2_RE_16_V, VL_4_RE_32_V, VL_8_RE_64_V}; // required for when the data actually comes back
    end else begin
      assign whole_reg_rd = 1'b0;
      assign whole_reg_ld = 1'b0;
    end

    // FIXME-CARO only helps if avl < single logic lol
    if (ENABLE_64_BIT) begin
      assign width_store = opcode_mnr[1:0];
    end else begin
      assign width_store = `MIN(opcode_mnr[1:0], 2'b10);
    end

    function logic [OFF_BITS-1:0] get_max_off (logic [VLEN_B_BITS+1-1:0] avl,
                                               logic [VLEN_B_BITS+1-1:0] avl_eff,
                                               logic [2-1:0] sew,
                                               logic [32-1:0] max_off);
      return avl > (VLEN_B >> sew) ? max_off - 1 : avl_eff >> (DW_B_BITS - sew);
    endfunction

    assign avl_max_off   = get_max_off(avl, avl_eff, sew,          VLEN_B/DW_B);
    assign avl_max_off_w = get_max_off(avl, avl_eff, alu_resp_sew, VLEN_B/DW_B);
    assign avl_max_off_l = get_max_off(avl, avl_eff, opcode_mnr_m, VLEN_B/DW_B);
    assign avl_max_off_s = get_max_off(avl, avl_eff, width_store,  VLEN_B/DW_B);

    if (MASK_ENABLE) begin
      assign avl_max_off_m   = get_max_off(avl, avl_eff/8, sew, (VLEN_B/DW_B)/8);
      assign avl_max_off_w_m = get_max_off(avl, avl_eff/8, alu_resp_sew, (VLEN_B/DW_B)/8);

      assign avl_max_off_in_rd = is_vmask_op ? (is_vstore ? avl_max_off_s_m : avl_max_off_m):
                                               (is_vstore ? avl_max_off_s   : avl_max_off);
      assign avl_max_off_in_wr = alu_resp_mask ? avl_max_off_w_m : avl_max_off_w; //Note: -> m -> w_m
    end else begin
      assign avl_max_off_in_rd = is_vstore ? avl_max_off_s : avl_max_off;
      assign avl_max_off_in_wr = avl_max_off_w;
    end

    if (MASK_ENABLE_EXT) begin
      assign avl_max_off_l_m = get_max_off(avl, avl_eff/8, opcode_mnr_m, (VLEN_B/DW_B)/8);
      assign avl_max_off_s_m = get_max_off(avl, avl_eff/8, width_store,  (VLEN_B/DW_B)/8);

      assign avl_max_off_in_ld = wait_mem_msk ? avl_max_off_l_m : avl_max_off_l;
    end else begin
      assign avl_max_off_in_ld = avl_max_off_l;
      assign avl_max_off_s_m   = avl_max_off_s;
    end

    assign avl_max_reg   = avl_eff >> (VLEN_B_BITS - sew);
    assign avl_max_reg_s = avl_eff >> (VLEN_B_BITS - width_store);
    assign avl_max_reg_l = avl_eff >> (VLEN_B_BITS - opcode_mnr_m);
    assign avl_max_reg_w = avl_eff >> (VLEN_B_BITS - alu_resp_sew);

    if (SLIDE_N_ENABLE) begin
      // read later offsets for slide down 
      always_comb begin
        unique casez (insn_in_f)
          VSLIDEDOWN_VI,
          VSLIDEDOWN_VX:  rd_off_in = sca_data_in_1 >> (DW_B_BITS - sew);
          VSLIDE1DOWN_VX: rd_off_in = 'h0;
          default: rd_off_in = 'h0;
        endcase
      end

      assign dest_off_in = alu_resp_off;
    end else begin
      assign rd_off_in   = 'h0;
      assign dest_off_in = 'h0;
    end

    // ---------------------------------------- ALU CONTROL --------------------------------------------------------------------------

    // hold values steady while waiting for multiple register groupings
    always_comb begin
      if (reg_count == 0) begin
        hold_reg_group = is_vstore | is_vload | is_valu; //Note: MASK_ENABLE for is_alu? //FIXME-JO
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

      if (~rst_n)
        alu_req_vr_idx <= 'h0;
    end

    always_comb begin
      if (whole_reg_rd) begin
        reg_count_avl = VLEN_B - 1;
      end else if (widen_en) begin
        reg_count_avl = 2 * avl_eff; //Note: Update size???
      end else begin
        reg_count_avl = avl_eff;
      end
    end

    always_ff @(posedge clk) begin
      if (reg_count == 0) begin
        if (hold_reg_group & ~stall) begin
          if (is_vmask_op) begin
            reg_count <= reg_count_avl >> (DW_B_BITS + 3);
            //reg_count_avl * 1 / DATA_WIDTH
          end else if (is_valu | is_vcfg) begin
            reg_count <= reg_count_avl >> (DW_B_BITS - sew);
            //reg_count_avl * SEW_WIDTH / DATA_WIDTH
          end else begin
            reg_count <= reg_count_avl >> (DW_B_BITS - width_store);
            //reg_count_avl * LS_WIDTH / DATA_WIDTH
          end
        end
      end else begin
        reg_count <= reg_count - 1;
      end

      if (~rst_n)
        reg_count <= 'h0;
    end

    // ALU INPUTS
    always_ff @(posedge clk) begin
      alu_req_start <= agu_addr_start_rd_1 | agu_addr_start_rd_2 | (insn_in_f inside {VALU_OPIVI, VALU_OPIVX, VID_V, VMV_SX, VMV_XS, VCPOP_M, VFIRST_M} & reg_count == 0);
      alu_req_end   <= agu_addr_end_rd_1   | agu_addr_end_rd_2   | (insn_in_d inside {VALU_OPIVI, VALU_OPIVX, VID_V, VMV_SX, VMV_XS, VCPOP_M, VFIRST_M} & reg_count == 1);
      alu_req_off   <= insn_in_d inside {VMSEQ_VV, VMSEQ_VX, VMSEQ_VI, VMSNE_VV, VMSNE_VX, VMSNE_VI, VMSLE_VV, VMSLE_VX, VMSLE_VI, VMSLEU_VV, VMSLEU_VX, VMSLEU_VI, VMSLT_VV, VMSLT_VX, VMSGT_VX, VMSGT_VI} ? alu_req_vr_idx_next >> (sew + 3) : vr_rd_off_1;

      if (~rst_n) begin
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
              unique case (sew)
                2'b00: alu_req_data0 = {DATA_WIDTH/8{sca_data_in_1_d[8-1:0]}};
                2'b01: alu_req_data0 = {DATA_WIDTH/16{sca_data_in_1_d[16-1:0]}};
                2'b10: alu_req_data0 = {DATA_WIDTH/32{sca_data_in_1_d[32-1:0]}};
                2'b11: alu_req_data0 = ENABLE_64_BIT & DATA_WIDTH >= 64 ? {DATA_WIDTH/64{sca_data_in_1_d[64-1:0]}}:
                                                                         {sca_data_in_1_d};
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
    if (MASK_ENABLE_EXT) begin
      assign is_vmask_op = insn_in_f inside {VMANDNOT_MM, VMAND_MM, VMOR_MM, VMXOR_MM, VMORNOT_MM, VMNAND_MM, VMNOR_MM, VMXNOR_MM, VCPOP_M, VFIRST_M, VSM_V};
    end else if (MASK_ENABLE) begin
      assign is_vmask_op = insn_in_f inside {VMANDNOT_MM, VMAND_MM, VMOR_MM, VMXOR_MM, VMORNOT_MM, VMNAND_MM, VMNOR_MM, VMXNOR_MM};
    end else begin
      assign is_vmask_op = 'b0;
    end

    assign is_valu   = insn_in_f inside {VALU_CFG} & ~(insn_in_f inside {VCFG});
    assign is_vcfg   = insn_in_f inside {VCFG};
    assign is_vload  = insn_in_f inside {VLOAD};
    assign is_vstore = insn_in_f inside {VSTORE};

    assign uses_rd   = insn_in_f inside {VCFG} | insn_in_f inside {VMV_XS, VCPOP_M, VFIRST_M};
    assign uses_vd   = insn_in_f inside {VLOAD} | (insn_in_f inside {VALU_OPIVV, VALU_OPMVV, VALU_OPIVI, VALU_OPIVX, VALU_OPMVX} & ~(insn_in_f inside {VMV_XS, VCPOP_M, VFIRST_M}));
    assign uses_vs1  = insn_in_f inside {VALU_OPIVV, VALU_OPMVV} & ~(insn_in_f inside {VID_V, VMV_XS, VCPOP_M, VFIRST_M});
    assign uses_vs2  = insn_in_f inside {VALU_OPIVV, VALU_OPMVV, VALU_OPIVI, VALU_OPIVX, VALU_OPMVX} & ~(insn_in_f inside {VID_V, VMV_SX, VMV_VV, VMV_VX, VMV_VI}); // Note: Include indexed mops when layer added
    assign uses_vs3  = insn_in_f inside {VSTORE};
    assign uses_vm   = insn_in_f inside {VALU_CFG, VLOAD, VSTORE} & ~(insn_in_f inside {VCFG}) & ~(insn_in_f[25]);

    // used for ALU
    assign en_vd = alu_resp_valid & alu_resp_start & ~alu_resp_sca; // write data

    // used only for STORE-FP. OR with vs1, because there is no situation where vs1 and vs3 exist for the same insn
    assign en_mem_out = insn_in_d inside {VSTORE};

    // LOAD
    assign en_ld = ~agu_idle_ld;

    // make single write port!
    assign mem_port_ready_out = wait_mem & agu_idle_wr;

    always_comb begin
      if (agu_idle_ld) begin
        vr_in_en   = vr_wr_en;
        vr_in_addr = alu_resp_mask ? alu_resp_addr : vr_wr_addr;
        vr_in_off  = alu_resp_mask ? alu_resp_off  : vr_wr_off;
        vr_in_data = vr_wr_data_in;
      end else begin
        vr_in_en   = vr_ld_en;
        vr_in_addr = vr_ld_addr;
        vr_in_off  = vr_ld_off;
        vr_in_data = vr_ld_data_in;
      end
    end

    // ----------------------------------------------- REGFILE CONTROL --------------------------------------------------------------------
    // FIXME-CARO only read if mask op?

    assign vr_rd_en_1 = ~agu_idle_rd_1;
    assign vr_rd_en_2 = ~agu_idle_rd_2;

    always_ff @(posedge clk) begin
        // set "active" if we're reading mask or data --
        // all this does is enable the alu so it's fine. 
        vr_rd_valid_1 <= vr_rd_en_1;
        vr_rd_valid_2 <= vr_rd_en_2;
    end

    if (MASK_ENABLE) begin
      always_comb begin
        if (agu_idle_rd_2) begin
          vm_rd_en  = 1'b0;
          vm_rd_off = vr_rd_off_2;
        end else begin
          vm_rd_en  = (~vm_d | ~vm); //Note: Why vm_rd_en depends on agu_idle_rd_1?
          vm_rd_off = (~vm_d | (~vm & ~stall)) ? alu_req_vr_idx_next >> (sew + 3) : vr_rd_off_2;
        end
      end
    end

    // ----------------------------------------------------- MEMORY PORT LOGIC ----------------------------------------------------------------

    // memory could just run load/store in parallel with ALU if we implement queue

    // TODO update with mask ld/st
    assign mem_port_valid_out = en_mem_out;
    assign mem_port_addr_out  = mem_addr_in_d; // why bother checking validity? thats what the valid signal is for...
    assign mem_port_be_out = {(MEM_DW_B){1'b1}};
    assign mem_port_data_out = vr_rd_data_out_1;

    // LOAD
    assign vr_ld_data_in = r_data;
    assign vr_ld_ack = r_valid;
    assign vr_ld_en = {DW_B{en_ld}};

    // --------------------------------------------------- WRITEBACK STAGE LOGIC --------------------------------------------------------------
    assign vr_wr_en = agu_idle_wr ? 'h0 : alu_resp_be;
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
    assign no_bubble = hold_reg_group & reg_count != 0;

    always_comb begin
      sca_data_in_2 = (DATA_WIDTH)'(data_in_2_f);

      unique casez (insn_in_f)
        VALU_OPIVI: begin
          unique casez (insn_in_f)
            VSLIDEUP_VI, VSLIDEDOWN_VI: sca_data_in_1 = (DATA_WIDTH)'(src_1); //zimm
            default: sca_data_in_1 = (DATA_WIDTH)'(signed'(src_1));           //simm
          endcase
        end

        default: sca_data_in_1 = (DATA_WIDTH)'(data_in_1_f);
      endcase
    end

    // Adding byte enable for ALU
    always_comb begin
      if (insn_in_d inside {VMV_SX, VMV_XS}) begin //Note: VCPOP_M? VFIRST_M? 
        if (alu_req_vr_idx == 0) begin
          unique case (sew)
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
      .AVL_WIDTH(VLEN_B_BITS+1), 
      .SEW_WIDTH(2), 
      .ENABLE_64_BIT(ENABLE_64_BIT)) 
    generate_be_block (
      .sew(sew), 
      .avl(avl), 
      .avl_dw_offset(widen_en_d ? 2 * alu_req_vr_idx : alu_req_vr_idx), 
      .avl_be(avl_be));

    always_ff @(posedge clk) begin
      if(~rst_n) begin
        dest_d <= 'b0;
        funct6_d <= 'b0;
        insn_in_d <= 'b0;
        opcode_mjr_d <= 'b0;
        opcode_mnr_d <= 'b0;
        sca_data_in_1_d <= 'b0;
        sca_data_in_2_d <= 'b0;
        vm_d <= 'b1; // unmasked by default
        vxrm_in_d <= 'b0;
        widen_en_d <= 'b0;

        mem_port_req_out<= 'b0;
        mem_addr_in_d <= 'b0;
        
        out_ack_e <= 'b0;
        out_data_e <= 'h0;
        out_ack_m <= 'b0;

        insn_in_m <= 'b0;
        opcode_mnr_m <= 'h0;
        dest_m <= 'h0;

        wait_mem <= 'b0;
        wait_mem_st <= 'b0;
        wait_mem_msk <= 'b0;

        vexrv_data_out <= 'h0;
        vexrv_valid_out <= 'h0;
      end else begin
        mem_addr_in_d <= mem_addr_in_d + DW_B;
        
        if (~stall) begin
          dest_d <= dest;
          funct6_d <= funct6;
          insn_in_d <= insn_in_f;
          opcode_mjr_d <= opcode_mjr;
          opcode_mnr_d <= opcode_mnr;
          sca_data_in_1_d <= sca_data_in_1;
          sca_data_in_2_d <= sca_data_in_2;
          vm_d <= vm;
          vxrm_in_d <= vxrm_in;
          widen_en_d <= widen_en;

          mem_port_req_out <= is_vload;
          mem_addr_in_d <= data_in_1_f;
        end else if (~no_bubble) begin
          dest_d <= 'b0;
          funct6_d <= 'b0;
          insn_in_d <= 'b0;
          opcode_mjr_d <= 'b0;
          opcode_mnr_d <= 'b0;
          sca_data_in_1_d <= 'b0;
          sca_data_in_2_d <= 'b0;
          vm_d <= 'b1;
          vxrm_in_d <= 'b0;
          widen_en_d <= 'b0;

          mem_port_req_out<= 'b0;
          mem_addr_in_d <= 'b0;
        end

        if (MASK_ENABLE == 0)
          vm_d <= 'b1;

        if (WIDEN_ADD_ENABLE | WIDEN_MUL_ENABLE)
          widen_en_d <= 'b0;

        if (~wait_mem || (r_valid && r_last)) begin
          insn_in_m <= insn_in_d;
          dest_m <= dest_d;
          opcode_mnr_m <= opcode_mnr_d[1:0];
          if (ENABLE_64_BIT == 0)
            opcode_mnr_m <= `MIN(opcode_mnr_d[1:0], 2'b10);
        end

        if (insn_in_d inside {VLOAD})
          wait_mem <= 1'b1;
        if (r_valid && r_last)
          wait_mem <= 1'b0;

        if (insn_in_d inside {VSTORE})
          wait_mem_st <= 1'b1;
        if (b_valid)
          wait_mem_st <= 1'b0;

        if (insn_in_d inside {VLM_V})
          wait_mem_msk <= 1'b1;
        if (r_last && r_valid)
          wait_mem_msk <= 1'b0;
        if (MASK_ENABLE_EXT == 0)
          wait_mem_msk <= 1'b0;

        out_ack_e  <= alu_resp_valid & alu_resp_end;
        out_data_e <= alu_resp_sca ? alu_resp_data[VEX_DATA_WIDTH-1:0] : 'h0; //FIXME
        out_ack_m  <= (r_valid & r_last) | b_valid;

        vexrv_data_out <= (insn_in_d inside {VCFG} & new_vl) ? avl : out_data_e;
        vexrv_valid_out <= out_ack_e | out_ack_m | (insn_in_d inside {VCFG} & new_vl);
      end
    end

    /* AXI READ ADDRESS LOGIC */
    assign ar_burst = 2'b01; // Incrementing
    assign ar_cache = 4'b0010; // Normal non-cacheable non-bufferable
    assign ar_id = 6'h4;
    assign ar_size = 3'b011; // 8 bytes - 64 bits

    always_ff @(posedge clk) begin
      if (~ar_valid) begin
        if (is_vload & ~stall) begin
          ar_valid <= 1'b1;
          ar_addr <= data_in_1_f;
          ar_len <= (reg_count_avl >> (DW_B_BITS - width_store));
        end
      end else if (ar_ready) begin
        ar_valid <= 1'b0;
      end

      if (~rst_n) begin
        ar_valid <= 1'b0;
        ar_addr <= 'b0;
        ar_len <= 'b0;
      end
    end

    /* AXI READ DATA LOGIC */
    assign r_ready = 1; 

    /* AXI WRITE ADDRESS LOGIC */
    assign aw_burst = 2'b01; // Incrementing
    assign aw_cache = 4'b0010; // Normal non-cacheable non-bufferable
    assign aw_id = 6'h5;
    assign aw_size = 3'b011; // 8 bytes - 64 bits

    always_ff @(posedge clk) begin
      if (~aw_valid) begin
        if (is_vstore & ~stall) begin
          aw_valid <= 1'b1;
          aw_addr <= data_in_1_f;
          aw_len <= (reg_count_avl >> (DW_B_BITS - width_store)); // Note: reg_count_avl already set 
        end
      end else if (aw_ready) begin
        aw_valid <= 1'b0;
      end

      if (~rst_n) begin
        aw_valid <= 1'b0;
        aw_addr <= 'b0;
        aw_len <= 'b0;
      end
    end

    //////////////////////////
    // INVALIDATION
    // FIXME
    
    logic [MEM_ADDR_WIDTH-1:0] inv_addr_max;

    always_ff @(posedge clk) begin
      inv_valid <= 1'b0;

      if (aw_ready == 1'b1 && aw_valid == 1'b1) begin
        inv_addr <= aw_addr;
        inv_addr_max <= aw_addr + 4*2*aw_len; 
        inv_valid <= 1'b1;
      end else if (inv_ack == 1'b1 && inv_addr != inv_addr_max) begin
        inv_addr <= inv_addr + 4;
        inv_valid <= 1'b1;
      end

      if (~rst_n) begin
        inv_addr <= 'b0;
        inv_addr_max <= 'b0;
        inv_valid <= 'b0;
      end
    end

    /* AXI WRITE DATA LOGIC */
    logic w_l_empty;
    logic mem_port_last_out;
    logic [DATA_WIDTH+1-1:0] w_last_data;

    FIFObuffer #(
      .DATA_WIDTH(DATA_WIDTH+1), 
      .DEPTH_BITS(`FIFO_DEPTH_BITS)) 
    w_buf_l (
      .clk(clk),
      .rst_n(rst_n),
      .r_en(w_ready & w_valid),
      .w_en(mem_port_valid_out),
      .data_in({mem_port_last_out, mem_port_data_out}),
      .data_out(w_last_data),
      .EMPTY(w_l_empty),
      .POP(),
      .FULL());

    assign mem_port_last_out = (reg_count == 0) && mem_port_valid_out;

    assign w_valid = ~w_l_empty;
    assign w_last = w_last_data[$high(w_last_data)];
    assign w_data = w_last_data[DATA_WIDTH-1:0];
    assign w_strb = {(DATA_WIDTH/8){1'b1}}; // FIXME-JO

    /* AXI WRITE RESPONSE LOGIC */
    assign b_ready = 1; 

    /////////////////////////////////////////////////////////////////////////////////
    logic alu_req_slide1;
    assign alu_req_slide1 = (opcode_mnr_d == `MVX_TYPE && funct6_d[5:1] == 5'b00111);
    
endmodule

module FIFObuffer#(
    parameter DATA_WIDTH  = 64,
    parameter DEPTH_BITS  = 4,
    parameter DEPTH = (1 << DEPTH_BITS)
)(
    input logic                       clk, 
    input logic                       r_en, 
    input logic                       w_en, 
    input logic                       rst_n,
    output logic                      EMPTY,
    output logic                      FULL,
    output logic     [DEPTH_BITS-1:0] POP,
    input logic      [DATA_WIDTH-1:0] data_in,
    output     [DATA_WIDTH-1:0] data_out
);
// internal registers

logic  [DEPTH_BITS-1:0]    count = 0; 
(*ram_decomp="power"*) logic  [DATA_WIDTH-1:0]    FIFO [0:DEPTH-1]; 
logic  [DEPTH_BITS-1:0]    r_count_d = 0, w_count_d = 0;
logic [DEPTH_BITS-1:0]    r_count, w_count;

assign EMPTY    = ~(|count);
assign FULL     = &count;
assign POP      = count;

assign data_out = FIFO[r_count_d];

assign w_count  = rst_n ? (w_count_d + (w_en & ~FULL)) : 'h0;
assign r_count  = rst_n ? (r_count_d + (r_en & ~EMPTY)) : 'h0;

always_ff @(posedge clk) begin
    w_count_d   <= w_count;
    r_count_d   <= r_count;
    count       <= w_count - r_count;
end

always_ff @(posedge clk) begin
    if (rst_n & w_en & ~FULL) begin
        FIFO[w_count_d] <= data_in;
    end
end
endmodule

module extract_mask 
  #(
    parameter VLEN          = 16384,
    parameter DATA_WIDTH    = 64,
    parameter DW_B          = DATA_WIDTH/8,
    parameter DW_B_BITS     = $clog2(DW_B),
    parameter SEW_WIDTH     = 2,
    parameter OFF_BITS      = $clog2(VLEN/DATA_WIDTH),
    parameter ENABLE_64_BIT = 1
  )
  (
    input  logic [SEW_WIDTH-1:0] sew,
    input  logic [OFF_BITS-1:0] dw_offset,
    input  logic mask_en,
    input  logic [DATA_WIDTH-1:0] mask_data,
    output logic [DW_B-1:0] mask_be
  );

  localparam NUM_SEWS = 1 << SEW_WIDTH;
  logic [DW_B-1:0] mask_bes[NUM_SEWS];
  logic [OFF_BITS+DW_B_BITS-1:0] b;
  logic [OFF_BITS-1:0] y;
  logic [DW_B_BITS-1:0] x;
  logic [DW_B-1:0] d;

  genvar j, o;

  for (j = 0; j < NUM_SEWS-1; j++) begin
    localparam W_B = 1 << j;
    for (o = 0; o < DW_B/W_B; o++) begin
      always_comb begin
        b = (OFF_BITS+DW_B_BITS)'(dw_offset) * DW_B/W_B;
        {y,x} = (OFF_BITS+DW_B_BITS)'(b+o);
        d = mask_data[y*DW_B +: DW_B];
        mask_bes[j][o*W_B +: W_B] = {W_B{d[x]}};
      end
    end
  end

  if (ENABLE_64_BIT) begin
    localparam W_B = 1 << (NUM_SEWS-1);
    for (o = 0; o < DW_B/W_B; o++) begin
      always_comb begin
        b = (OFF_BITS+DW_B_BITS)'(dw_offset) * DW_B/W_B;
        {y,x} = (OFF_BITS+DW_B_BITS)'(b+o);
        d = mask_data[y*DW_B +: DW_B];
        mask_bes[NUM_SEWS-1][o*W_B +: W_B] = {W_B{d[x]}};
      end
    end
  end else begin
    assign mask_bes[NUM_SEWS-1] = 'h0;
  end

  assign mask_be = mask_en ? mask_bes[sew] : {DW_B{1'b1}};

endmodule

module generate_be 
  #(
    parameter VLEN          = 16384,
    parameter AVL_WIDTH     = $clog2(VLEN/8)+1,
    parameter DATA_WIDTH    = 64,
    parameter DW_B          = DATA_WIDTH/8,
    parameter DW_B_BITS     = $clog2(DW_B),
    parameter SEW_WIDTH     = 2,
    parameter ENABLE_64_BIT = 1
  ) 
  (
    input  logic [SEW_WIDTH-1:0] sew,
    input  logic [AVL_WIDTH-1:0] avl,
    input  logic [AVL_WIDTH-1:0] avl_dw_offset,
    output logic [DW_B-1:0] avl_be
  );

  localparam NUM_SEWS = 1 << SEW_WIDTH;
  logic [DW_B-1:0] avl_bes [NUM_SEWS];
  logic [AVL_WIDTH-1:0] b;

  genvar j, o;

  // Generate mask byte enable based on SEW and current index in vector
  for (j = 0; j < NUM_SEWS-1; j++) begin
    localparam W_B = 1 << j;
    for (o = 0; o < DW_B/W_B; o++) begin
      always_comb begin
        b = (AVL_WIDTH)'(avl_dw_offset) * DW_B/W_B;
        avl_bes[j][o*W_B +: W_B] = (AVL_WIDTH)'(b+o) < avl ? {W_B{1'b1}} : {W_B{1'b0}};
      end
    end
  end

  if (ENABLE_64_BIT) begin
    localparam W_B = 1 << (NUM_SEWS-1);
    for (o = 0; o < DW_B/W_B; o++) begin
      always_comb begin
        b = (AVL_WIDTH)'(avl_dw_offset) * DW_B/W_B;
        avl_bes[NUM_SEWS-1][o*W_B +: W_B] = (AVL_WIDTH)'(b+o) < avl ? {W_B{1'b1}} : {W_B{1'b0}};
      end
    end
  end else begin
    assign avl_bes[NUM_SEWS-1] = 'h0;
  end

  assign avl_be = avl_bes[sew];

endmodule
