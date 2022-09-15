`include "vec_regfile.sv"
`include "mask_regfile.sv"
`include "insn_decoder.sv"
`include "addr_gen_unit.sv"
`include "cfg_unit.sv"
`include "vALU/vALU.v"

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

`define AND_OR_XOR_ENABLE 1 // a1b
`define ADD_SUB_ENABLE    1 // 
`define MIN_MAX_ENABLE    1 // a1c
`define VEC_MOVE_ENABLE   1 // a1d
`define WHOLE_ENABLE      1 // a1e
`define SLIDE_ENABLE      1 // a1f
`define WIDEN_ADD_ENABLE  1 // a2
`define REDUCTION_ENABLE  1 // a3
`define MULT_ENABLE       1 // a4a
`define SHIFT_ENABLE      1
`define MULH_SR_ENABLE    1 // a4b
`define MULH_SR_32_ENABLE 1 // a5a  6,701, 171.6
`define WIDEN_MUL_ENABLE  1 // a5b  6,839, 
`define NARROW_ENABLE     1 
`define SLIDE_N_ENABLE    0 // a6
`define MULT64_ENABLE     0 // a7
`define SHIFT64_ENABLE    0 
`define FXP_ENABLE        0 // a8
`define MASK_ENABLE       0 // b1

module rvv_proc_main #(
    parameter VLEN              = 16384,            // vector length in bits
    parameter VLEN_B            = VLEN >> 3,        // same as VLMAX
    parameter VLEN_B_BITS       = 12,
    parameter XLEN              = 32,               // not sure, data width maybe?
    parameter NUM_VEC           = 32,               // number of available vector registers
    parameter INSN_WIDTH        = 32,               // width of a single instruction
    parameter DATA_WIDTH        = 64,
    parameter DATA_WIDTH_BITS   = 6,
    parameter DW_B              = DATA_WIDTH>>3,    // DATA_WIDTH in bytes
    parameter DW_B_BITS         = DATA_WIDTH_BITS-3,
    parameter ADDR_WIDTH        = 5,                // 5 bits for 32 vector regs
    parameter MEM_ADDR_WIDTH    = 32,               // We need to get this from VexRiscV
    parameter MEM_DATA_WIDTH    = 64,
    parameter MEM_DW_B          = MEM_DATA_WIDTH>>3,
    parameter VEX_DATA_WIDTH    = 32,
    parameter BYTE              = 8,
    parameter OFF_BITS          = 8                 // max value is 256 (16384/64)
) (
    input                               clk,
    input                               rst_n,
    input       [    INSN_WIDTH-1:0]    insn_in, // make this a queue possibly
    input                               insn_valid,
    input       [               2:0]    vxrm_in,
    input       [    DATA_WIDTH-1:0]    mem_port_data_in,
    input                               mem_port_valid_in,
    input                               mem_port_done_ld,
    input                               mem_port_done_st,
    input       [VEX_DATA_WIDTH-1:0]    vexrv_data_in_1,    // memory address from load/store command
    input       [VEX_DATA_WIDTH-1:0]    vexrv_data_in_2,
    output      [MEM_DATA_WIDTH-1:0]    mem_port_data_out,
    output      [MEM_ADDR_WIDTH-1:0]    mem_port_addr_out,
    output reg                          mem_port_req_out,       // signal dicating request vs write
    output                              mem_port_valid_out,
    output      [      MEM_DW_B-1:0]    mem_port_be_out,
    output reg                          mem_port_start_out,
    output                              mem_port_ready_out,
    output                              proc_rdy,
    output reg  [VEX_DATA_WIDTH-1:0]    vexrv_data_out,   // anything writing to a scalar register should already know the dest register
    output reg                          vexrv_valid_out
);
    wire                        vr_rd_en_1;
    wire                        vr_rd_en_2;
    wire  [          DW_B-1:0]  vr_wr_en;
    wire  [          DW_B-1:0]  vr_ld_en;
    wire  [          DW_B-1:0]  vr_in_en;
    
    wire  [          DW_B-1:0]  vmask_ext;

    wire                        vm_rd_en_1;
    wire                        vm_rd_en_2;
    wire  [          DW_B-1:0]  vm_wr_en;
    wire  [          DW_B-1:0]  vm_ld_en;
    wire  [          DW_B-1:0]  vm_in_en;

    reg                         vr_rd_active_1;
    reg                         vr_rd_active_2;

    wire  [    ADDR_WIDTH-1:0]  vr_rd_addr_1;
    wire  [    ADDR_WIDTH-1:0]  vr_rd_addr_2;
    wire  [    ADDR_WIDTH-1:0]  vr_wr_addr;
    wire  [    ADDR_WIDTH-1:0]  vr_ld_addr;
    wire  [    ADDR_WIDTH-1:0]  vr_in_addr;

    wire  [      OFF_BITS-1:0]  vr_rd_off_1;
    wire  [      OFF_BITS-1:0]  vr_rd_off_2;
    wire  [      OFF_BITS-1:0]  vr_wr_off;
    wire  [      OFF_BITS-1:0]  vr_ld_off;
    wire  [      OFF_BITS-1:0]  vr_in_off;

    wire  [      OFF_BITS-1:0]  vm_in_off;
    wire  [      OFF_BITS-1:0]  vm_rd_off_1;
    wire  [    ADDR_WIDTH-1:0]  vm_in_addr;
    wire  [    ADDR_WIDTH-1:0]  vm_rd_addr_1;

    wire  [    DATA_WIDTH-1:0]  vr_wr_data_in;
    wire  [    DATA_WIDTH-1:0]  vr_rd_data_out_1;
    wire  [    DATA_WIDTH-1:0]  vr_rd_data_out_2;
    wire  [    DATA_WIDTH-1:0]  vr_ld_data_in;
    wire  [    DATA_WIDTH-1:0]  vr_in_data;

    wire  [    DATA_WIDTH-1:0]  vm_ld_data_in;
    wire  [    DATA_WIDTH-1:0]  vm_in_data;
    wire  [    DATA_WIDTH-1:0]  vm_rd_data_out_1;
    wire  [    DATA_WIDTH-1:0]  vm_rd_data_out_2; 

    reg   [    INSN_WIDTH-1:0]  insn_in_f;
    reg   [VEX_DATA_WIDTH-1:0]  data_in_1_f;
    reg   [VEX_DATA_WIDTH-1:0]  data_in_2_f;
    reg   [               1:0]  vxrm_in_f;

    wire                        stall;

    wire                        en_req_mem;
    reg                         en_req_mem_d;
    wire                        en_mem_out;
    reg   [MEM_ADDR_WIDTH-1:0]  mem_addr_in_d;

    // insn decomposition -- mostly general
    wire  [               6:0]  opcode_mjr;
    wire  [               2:0]  opcode_mnr;
    wire  [               4:0]  dest;    // rd, vd, or vs3 -- TODO make better name lol
    wire  [               4:0]  src_1;   // rs1, vs1, or imm/uimm
    wire  [               4:0]  src_2;   // rs2, vs2, or imm -- for mem could be lumop, sumop

    // vmem
    wire  [               2:0]  width;
    wire  [               1:0]  mop;
    wire                        mew;
    wire  [               2:0]  nf;

    wire                        mask_en;

    // vcfg
    wire  [              10:0]  vtype_11;
    wire  [               9:0]  vtype_10;
    wire  [               1:0]  cfg_type;
    wire                        cfg_en;

    // valu
    wire                        vm;
    wire  [               5:0]  funct6;

    // Use these to determine where hazards will fall
    wire                        req_vs1;
    wire                        req_vs2;
    wire                        req_vs3;
    wire                        req_vd;

    reg   [ VEX_DATA_WIDTH-1:0] sca_data_in_1;
    reg   [ VEX_DATA_WIDTH-1:0] sca_data_in_2;

    wire                        en_vs1;
    wire                        en_vs2;
    wire                        en_vs3;
    wire                        en_vd;
    wire                        en_ld;

    // value propagation signals
    reg   [               6:0]  opcode_mjr_d;
    reg   [               2:0]  opcode_mnr_d;
    reg   [               4:0]  dest_d;    // rd, vd, or vs3 -- TODO make better name lol
    reg   [               4:0]  lumop_d;
    reg   [               1:0]  mop_d;
    reg   [               5:0]  funct6_d;
    reg                         vm_d;
    reg   [   VLEN_B_BITS-1:0]  avl_d;
    reg   [VEX_DATA_WIDTH-1:0]  sca_data_in_1_d;
    reg   [VEX_DATA_WIDTH-1:0]  sca_data_in_2_d;
    reg   [               1:0]  vxrm_in_d;

    reg   [               6:0]  opcode_mjr_m;
    reg   [               4:0]  dest_m;    // rd, vd, or vs3 -- TODO make better name lol
    reg   [               4:0]  lumop_m;
    reg   [               1:0]  mop_m;

    reg                         out_ack_e;
    reg   [VEX_DATA_WIDTH-1:0]  out_data_e;
    reg                         out_ack_m;

    // CONFIG VALUES -- config unit flops them, these are just connector wires
    wire  [   VLEN_B_BITS-1:0]  avl; // Application Vector Length (vlen effective)
    wire  [   VLEN_B_BITS-1:0]  avl_eff; // avl - 1
    wire  [   VLEN_B_BITS-1:0]  reg_count_avl; // avl - 1
    wire                        new_vl;

    // VTYPE values
    wire  [               1:0]  sew; // we dont do fractional
    wire  [          XLEN-1:0]  vtype;
    wire                        vill;

    wire  [          XLEN-1:0]  vtype_nxt;
    wire  [               1:0]  avl_set;
    reg   [   VLEN_B_BITS-2:0]  reg_count;

    wire                        agu_idle_rd_1;
    wire                        agu_idle_rd_2;
    wire                        agu_idle_wr;
    wire                        agu_idle_ld;
    wire                        agu_idle_st;

    wire                        alu_enable;
    reg   [               1:0]  alu_req_vxrm;
    // wire  [               2:0]  alu_req_sew;
    // wire  [VEX_DATA_WIDTH-1:0]  alu_req_avl;
    
    wire  [    DATA_WIDTH-1:0]  s_ext_imm;
    reg   [    DATA_WIDTH-1:0]  s_ext_imm_d;

    reg   [    DATA_WIDTH-1:0]  alu_data_in1;
    reg   [    DATA_WIDTH-1:0]  alu_data_in2;
    wire  [    DATA_WIDTH-1:0]  alu_data_out;

    wire  [    ADDR_WIDTH-1:0]  alu_addr_out;
    wire  [      OFF_BITS-1:0]  alu_req_off;
    reg   [      OFF_BITS-1:0]  alu_off_agu;
    wire  [      OFF_BITS-1:0]  alu_off_out;
    wire                        alu_valid_out;
    wire  [   VLEN_B_BITS-1:0]  alu_avl_out;
    wire                        alu_mask_out;
    wire                        alu_sca_out;
    reg   [          DW_B-1:0]  alu_req_be;
    wire  [          DW_B-1:0]  alu_be_out;
    reg   [              11:0]  alu_vr_idx; // MAX VALUE IS 2047
    wire  [              11:0]  alu_vr_idx_next; // MAX VALUE IS 2047
    wire                        alu_out_w_reg; // whole register insn

    wire                        hold_reg_group;
    reg                         vec_haz         [0:NUM_VEC-1]; // use this to indicate that vec needs bubble????
    wire                        vec_haz_set     [0:NUM_VEC-1]; // use this to indicate that vec needs bubble????
    wire                        vec_haz_clr     [0:NUM_VEC-1]; // use this to indicate that vec needs bubble????
    wire                        no_bubble;

    reg   [    ADDR_WIDTH-1:0]  ld_addr;
    reg   [    DATA_WIDTH-1:0]  ld_data_in;
    reg                         ld_valid;
    reg                         wait_mem;
    reg                         wait_mem_msk;

    // Detect hazards for operands
    wire                        haz_src1;
    wire                        haz_src2;
    wire                        haz_dest;

    wire                        logic_mop;

    wire                        agu_addr_start_rd_1,    agu_addr_start_rd_2,    agu_addr_start_wr;
    wire                        agu_addr_end_rd_1,      agu_addr_end_rd_2,      agu_addr_end_wr;
    reg                         alu_req_start,  alu_req_end;
    wire                        alu_resp_start, alu_resp_end;
    wire  [               1:0]  alu_resp_sew;

    wire  [      OFF_BITS-1:0]  avl_max_off;
    wire  [      OFF_BITS-1:0]  avl_max_off_m;
    wire  [      OFF_BITS-1:0]  avl_max_off_w;
    wire  [      OFF_BITS-1:0]  avl_max_off_in_rd;
    wire  [               2:0]  avl_max_reg;
    wire  [               2:0]  avl_max_reg_w;

    wire  [      OFF_BITS-1:0]  avl_max_off_in_ld;
    wire  [      OFF_BITS-1:0]  avl_max_off_in_wr;

    wire                        whole_reg_rd;
    wire                        whole_reg_ld;

    wire  [          DW_B-1:0]  gen_avl_be;
    reg                  [2:0]  mask_off [0:3];

    wire                        widen_en;
    reg                         widen_en_d;

    genvar i,j;
    integer k;

    //   wire alu_req_ready;
    //   wire alu_req_vl_out;

    // -------------------------------------------------- CONNECTED MODULES ---------------------------------------------------------------------------------

    insn_decoder #(.INSN_WIDTH(INSN_WIDTH)) id (.insn_in(insn_in_f), .opcode_mjr(opcode_mjr), .opcode_mnr(opcode_mnr), .dest(dest), .src_1(src_1), .src_2(src_2),
        .width(width), .mop(mop), .mew(mew), .nf(nf), .vtype_11(vtype_11), .vtype_10(vtype_10), .vm(vm), .funct6(funct6), .cfg_type(cfg_type));

    // TODO: figure out how to make this single cycle, so we can fully pipeline lol
    addr_gen_unit #(.ADDR_WIDTH(ADDR_WIDTH),.DATA_WIDTH(DATA_WIDTH),.VLEN(VLEN)) agu_src1   (.clk(clk), .rst_n(rst_n), .en((en_vs1 | en_vs3) & ~stall), .sew(logic_mop ? 'h0 : sew),.whole_reg(whole_reg_rd),.addr_in(en_vs1 ? src_1 : dest),.addr_out(vr_rd_addr_1),.max_reg_in(logic_mop ? 'h0 : avl_max_reg),.max_off_in(avl_max_off_in_rd), .off_out(vr_rd_off_1),  .idle(agu_idle_rd_1),   .addr_start(agu_addr_start_rd_1),   .addr_end(agu_addr_end_rd_1), .widen(widen_en | widen_en_d));
    addr_gen_unit #(.ADDR_WIDTH(ADDR_WIDTH),.DATA_WIDTH(DATA_WIDTH),.VLEN(VLEN)) agu_src2   (.clk(clk), .rst_n(rst_n), .en(en_vs2 & ~stall),            .sew(logic_mop ? 'h0 : sew),.whole_reg(whole_reg_rd),.addr_in(src_2),                .addr_out(vr_rd_addr_2),.max_reg_in(logic_mop ? 'h0 : avl_max_reg),.max_off_in(avl_max_off_in_rd), .off_out(vr_rd_off_2),  .idle(agu_idle_rd_2),   .addr_start(agu_addr_start_rd_2),   .addr_end(agu_addr_end_rd_2), .widen(widen_en | widen_en_d));
    addr_gen_unit #(.ADDR_WIDTH(ADDR_WIDTH),.DATA_WIDTH(DATA_WIDTH),.VLEN(VLEN)) agu_dest   (.clk(clk), .rst_n(rst_n), .en(en_vd),                      .sew(alu_resp_sew),         .whole_reg(alu_out_w_reg),.addr_in(alu_addr_out),        .addr_out(vr_wr_addr),  .max_reg_in(alu_mask_out ? 'h0 : avl_max_reg_w),.max_off_in(avl_max_off_in_wr), .off_out(vr_wr_off),    .idle(agu_idle_wr));
    addr_gen_unit #(.ADDR_WIDTH(ADDR_WIDTH),.DATA_WIDTH(DATA_WIDTH),.VLEN(VLEN)) agu_ld     (.clk(clk), .rst_n(rst_n), .en(ld_valid&mem_port_valid_in), .sew(sew),                  .whole_reg(whole_reg_ld),.addr_in(dest_m),               .addr_out(vr_ld_addr),  .max_reg_in(wait_mem_mask ? 'h0 : avl_max_reg),.max_off_in(avl_max_off_in_ld), .off_out(vr_ld_off),    .idle(agu_idle_ld));

    // TODO: make this a proper ("true dual-port ram")
    vec_regfile #(.VLEN(VLEN), .DATA_WIDTH(DATA_WIDTH), .ADDR_WIDTH(ADDR_WIDTH), .OFF_BITS(OFF_BITS)) vr (.clk(clk),.rst_n(rst_n),
                .rd_en_1(vr_rd_en_1),             .rd_en_2(vr_rd_en_2),               .wr_en(vr_in_en),     
                .rd_addr_1(vr_rd_addr_1),         .rd_addr_2(vr_rd_addr_2),           .wr_addr(vr_in_addr), 
                .rd_off_1(vr_rd_off_1),           .rd_off_2(vr_rd_off_2),             .wr_off(vr_in_off),   
                .rd_data_out_1(vr_rd_data_out_1), .rd_data_out_2(vr_rd_data_out_2),   .wr_data_in(vr_in_data));

    // TODO: make this a proper "true dual-port ram"
    generate
        if (`MASK_ENABLE) begin : mask_file
            mask_regfile #(.VLEN(VLEN), .DATA_WIDTH(DATA_WIDTH), .ADDR_WIDTH(ADDR_WIDTH), .OFF_BITS(OFF_BITS)) vmr (.clk(clk),.rst_n(rst_n),
                        .rd_en_1(vm_rd_en_1),           .rd_en_2(vm_rd_en_2),               .wr_en(vm_in_en),    
                        .rd_addr_1(vm_rd_addr_1),       .rd_addr_2(vr_rd_addr_2),           .wr_addr(vm_in_addr),
                        .rd_off_1(vm_rd_off_1),         .rd_off_2(vr_rd_off_2),             .wr_off(vm_in_off),  
                        .rd_data_out_1(vm_rd_data_out_1), .rd_data_out_2(vm_rd_data_out_2),   .wr_data_in(vm_in_data));

            always @(posedge clk) begin
                mask_off[0] <= 0;
                mask_off[1] <= vr_rd_off_1[0] << 2;
                mask_off[2] <= vr_rd_off_1[1:0] << 1;
                mask_off[3] <= vr_rd_off_1[2:0];
            end
            // FIXME
            extract_mask #(.DATA_WIDTH(DATA_WIDTH)) vm_alu (.en(~vm_d), .vmask_in(vm_rd_data_out_1[(vr_rd_off_1>>sew)*8 +: 8]), .sew(sew), .reg_off(mask_off[sew]), .vmask_out(vmask_ext));
        end else begin
            assign vmask_ext = {DW_B{1'b1}};
            assign vm_rd_data_out_1 = 'h0;
            assign vm_rd_data_out_2 = 'h0;
        end
    endgenerate
  
    cfg_unit #(.XLEN(XLEN), .VLEN(VLEN)) cfg_unit (.clk(clk), .en(cfg_en), .vtype_nxt(vtype_nxt), .cfg_type(cfg_type), .avl_set(avl_set),
        .avl_new(~(cfg_type[0] & cfg_type[1]) ? data_in_1_f : src_1), .avl(avl), .sew(sew), .vill(vill), .new_vl(new_vl));

    // TODO: update to use active low reset lol
    vALU #(.REQ_DATA_WIDTH(DATA_WIDTH), .RESP_DATA_WIDTH(DATA_WIDTH), .REQ_ADDR_WIDTH(ADDR_WIDTH), .REQ_VL_WIDTH(8),
            .AND_OR_XOR_ENABLE(`AND_OR_XOR_ENABLE),.ADD_SUB_ENABLE(`ADD_SUB_ENABLE),.MIN_MAX_ENABLE(`MIN_MAX_ENABLE),.VEC_MOVE_ENABLE(`VEC_MOVE_ENABLE),.WHOLE_REG_ENABLE(`WHOLE_ENABLE),
            .WIDEN_ADD_ENABLE(`WIDEN_ADD_ENABLE),.WIDEN_MUL_ENABLE(`WIDEN_MUL_ENABLE),.NARROW_ENABLE(`NARROW_ENABLE),.REDUCTION_ENABLE(`REDUCTION_ENABLE),.MULT_ENABLE(`MULT_ENABLE),
            .MULH_SR_ENABLE(`MULH_SR_ENABLE),.MULH_SR_32_ENABLE(`MULH_SR_32_ENABLE), .MULT64_ENABLE(`MULT64_ENABLE),.SHIFT_ENABLE(`SHIFT_ENABLE),.SLIDE_ENABLE(`SLIDE_ENABLE),
            .SLIDE_N_ENABLE(`SLIDE_N_ENABLE),.MASK_ENABLE(`MASK_ENABLE),.FXP_ENABLE(`FXP_ENABLE))
            alu (.clk(clk), .rst(~rst_n), .req_mask(vm_d), .req_be(alu_req_be), .req_vr_idx(alu_vr_idx), .req_start(alu_req_start), .req_end(alu_req_end), .req_whole_reg (alu_req_w_reg), .req_vxrm (vxrm_in_d),
        .req_valid(alu_enable), .req_op_mnr(opcode_mnr_d), .req_func_id(funct6_d), .req_sew(sew), .req_data0(alu_data_in1), .req_data1(alu_data_in2), .req_addr(dest_d), .req_off(alu_req_off),
        .resp_valid(alu_valid_out), .resp_data(alu_data_out), .req_addr_out(alu_addr_out), .req_vl(avl), .req_vl_out(alu_avl_out), .resp_mask_out(alu_mask_out), .req_be_out(alu_be_out),
        .resp_start(alu_resp_start), .resp_end(alu_resp_end), .resp_off(alu_off_out), .resp_whole_reg(alu_out_w_reg), .resp_sew(alu_resp_sew), .resp_sca_out(alu_sca_out));
    //  MISSING PORT CONNECTIONS:
    //     output                             req_ready   ,
    // );

    // -------------------------------------------------- FETCH AND HAZARD DETECTION -----------------------------------------------------------------------
    always @(posedge clk) begin
        insn_in_f       <= rst_n ? (stall ? insn_in_f : (insn_valid ? insn_in : 'h0)) : 'h0;
        data_in_1_f     <= (stall ? data_in_1_f : vexrv_data_in_1);
        data_in_2_f     <= (stall ? data_in_2_f : vexrv_data_in_2);
    end

    if (`FXP_ENABLE) begin : vxrm
        always @(posedge clk) begin
            vxrm_in_f       <= (stall ? vxrm_in_f   : vxrm_in[1:0]);
        end
    end

    // Hazard COUNT? IS THAT TOO MUCH?
    generate
        for (i = 0; i < NUM_VEC; i=i+1) begin : haz_logic
            // we shouldn't set the hazard unless we are actually processing a new instruction I think
            assign vec_haz_set[i] = (~stall & dest == i) & ((opcode_mjr == `OP_INSN & opcode_mnr != `CFG_TYPE) | en_req_mem);
            // testing to see if we can launch early if the next instruction isn't a mask op
            assign vec_haz_clr[i] = (dest_m == i & en_ld & (mem_port_done_ld | ~logic_mop)) |
                                    (alu_addr_out == i & alu_valid_out & (alu_resp_end | ~logic_mop));
                                    // right now we write to vm multiple times -- this should change to just generate one result and output the whole thing at once
            always @(posedge clk) begin
                // set high if incoming vector is going to overwrite the destination, or it has a hazard that isn't being cleared this cycle
                // else, set low
                vec_haz[i] <= rst_n & (vec_haz_set[i] | vec_haz[i]) & ~vec_haz_clr[i];
            end
        end
    endgenerate
  
    // FIXME this logic wouldn't work for v1 = v1 + v1
    assign haz_dest         = vec_haz[dest] & (en_vs1 | en_vs2 | en_vs3 | en_req_mem);
    assign haz_src1         = vec_haz[src_1] & en_vs1;
    assign haz_src2         = vec_haz[src_2] & en_vs2;

    assign wait_cfg         = (opcode_mjr_d == `OP_INSN & opcode_mnr_d == `CFG_TYPE);

    // Load doesn't really ever have hazards, since it just writes to a reg and that should be in order! Right?
    // WRONG -- CONSIDER CASE WHERE insn in the ALU path has the same dest addr. We *should* preserve write order there.

    // Just stall for WAW hazards for now
    // wait_mem included because the memory port can only handle one transaction at a time
    assign stall    = ~rst_n | (hold_reg_group & (|reg_count)) | haz_src1 | haz_src2 | haz_dest | wait_mem | wait_cfg;

    assign proc_rdy = ~stall;
    // ----------------------------------------- VTYPE CONTROL SIGNALS -------------------------------------------------------------------

    assign vtype_nxt = cfg_type[1] ? vtype_10 : vtype_11;
    assign cfg_en    = (opcode_mjr == `OP_INSN && opcode_mnr == `CFG_TYPE);
    assign avl_set   = {(dest == 'h0),(src_1 == 'h0)}; // determines if rd and rs1 are non-zero, as AVL setting depends on this


    if (`WIDEN_ADD_ENABLE | `WIDEN_MUL_ENABLE) begin
        assign widen_en  = (opcode_mjr == `OP_INSN && opcode_mnr != `CFG_TYPE && (&funct6[5:4] & ~funct6[2]));
    end else begin
        assign widen_en  = 0;
    end

    assign avl_eff   = avl - 1;

    generate
        if (`WHOLE_ENABLE) begin
            assign alu_req_w_reg = (funct6_d == 6'b100111 & opcode_mjr == `OP_INSN & opcode_mnr == `IVI_TYPE); // whole reg move

            // if (`WHOLE_ENABLE) begin
            assign whole_reg_rd   = (mop == 'h0 & src_2 == 'h8 & (opcode_mjr == `LD_INSN | opcode_mjr == `ST_INSN)) | (funct6_d[5:0] == 6'b100111 & opcode_mjr == `OP_INSN & opcode_mnr == `IVI_TYPE);
            assign whole_reg_ld   = (mop_m == 'h0 & lumop_m == 'h8 & opcode_mjr_m == `LD_INSN); // required for when the data actually comes back
            // end else begin
            //     assign whole_reg_rd   = (funct6_d == 6'b100111 & opcode_mjr == `OP_INSN & opcode_mnr == `IVI_TYPE);
            //     assign whole_reg_ld   = 0;
            // end
        end else begin
            assign whole_reg_rd = 0;
            assign alu_req_w_reg= 0;
            assign whole_reg_ld = 0;
        end
    endgenerate

    // FIXME only helps if avl < single reg lol
    assign avl_max_off   = (avl > (VLEN_B >> sew)) ? (VLEN_B/DW_B) - 1          : (avl_eff>>(DW_B_BITS - sew));
    assign avl_max_off_w = (avl > (VLEN_B >> alu_resp_sew)) ? (VLEN_B/DW_B) - 1 : (avl_eff>>(DW_B_BITS - alu_resp_sew));
    assign avl_max_off_m = (avl > (VLEN_B >> sew)) ? (VLEN_B/DATA_WIDTH) - 1    : (avl_eff>>(DATA_WIDTH_BITS - sew));

    assign avl_max_off_in_rd= logic_mop     ? avl_max_off_m : avl_max_off;
    assign avl_max_off_in_wr= alu_mask_out  ? avl_max_off_m : avl_max_off_w;
    assign avl_max_off_in_ld= wait_mem_msk  ? avl_max_off_m : avl_max_off;

    assign avl_max_reg    = avl_eff>>(VLEN_B_BITS - 1 - sew);
    assign avl_max_reg_w  = avl_eff>>(VLEN_B_BITS - 1 - alu_resp_sew);
    // ---------------------------------------- ALU CONTROL --------------------------------------------------------------------------

    // hold values steady while waiting for multiple register groupings
    assign hold_reg_group   = rst_n & ((|reg_count) | (reg_count == 0 & (en_vs3 | en_req_mem | (opcode_mjr == `OP_INSN & opcode_mnr != `CFG_TYPE) | (~logic_mop & avl > DW_B) | (logic_mop & avl > DATA_WIDTH))));

    // SIGN-EXTENDED IMMEDIATE FOR ALU
    assign s_ext_imm = {{(DATA_WIDTH-5){src_1[4]}}, src_1};
    assign alu_vr_idx_next = (|reg_count)    ? alu_vr_idx + 1 : 0;

    assign reg_count_avl = (whole_reg_rd ? VLEN_B - 1 : (widen_en ? 2*avl_eff : avl_eff));

    always @(posedge clk) begin
        if (~rst_n) begin
            reg_count   <= 'h0;
            alu_vr_idx  <= 'h0;
            s_ext_imm_d <= 'h0;
        end else begin
            reg_count   <= (|reg_count)    ? reg_count - 1 : (hold_reg_group ? (~logic_mop ? (reg_count_avl>>(DW_B_BITS - sew)) : reg_count_avl[VLEN_B_BITS-1:DATA_WIDTH_BITS]) : 0);
            alu_vr_idx  <= alu_vr_idx_next;
            s_ext_imm_d <= (~(|reg_count) & opcode_mjr == `OP_INSN) ? s_ext_imm : s_ext_imm_d; // latch value for register groupings
        end
    end


    // ALU INPUTS
    always @(posedge clk) begin
        if (~rst_n) begin
            alu_req_start   <= 'h0;
            alu_req_end     <= 'h0;
            alu_off_agu     <= 'h0;
        end else begin
            alu_req_start   <= agu_addr_start_rd_1 | agu_addr_start_rd_2 | ((opcode_mjr== `OP_INSN) & (opcode_mnr == `IVI_TYPE | (opcode_mnr == `MVV_TYPE & funct6 == 'h14) | (opcode_mnr[1:0] == 'h2 & funct6 == 6'h10)) & (reg_count == 0));
            alu_req_end     <= agu_addr_end_rd_1 | agu_addr_end_rd_2 | ((opcode_mjr_d == `OP_INSN) & (opcode_mnr_d == `IVI_TYPE | (opcode_mnr_d == `MVV_TYPE & funct6_d == 'h14) | (opcode_mnr_d[1:0] == 'h2 & funct6_d == 6'h10)) & (reg_count == 1));

            alu_off_agu     <= vr_rd_off_1; // FIXME - make generic
        end
    end

    // FIXME simplify
    assign alu_enable   = (opcode_mjr_d == `OP_INSN) & (  ((vr_rd_active_1 | vr_rd_active_2) & (opcode_mnr_d == `IVV_TYPE | opcode_mnr_d == `MVV_TYPE)) |
                                                            (opcode_mnr_d == `IVI_TYPE) | (opcode_mnr_d == `IVX_TYPE) | (opcode_mnr_d == `MVX_TYPE)   |
                                                            (opcode_mnr_d == `MVV_TYPE & funct6_d == 'h14) | (opcode_mnr_d[1:0] == 'h2 & funct6_d == 6'h10));

    assign alu_req_off  = (funct6_d[5:3] == 3'b011) & (opcode_mnr_d == `IVV_TYPE | opcode_mnr_d == `IVI_TYPE | opcode_mnr_d == `IVX_TYPE) ? (alu_vr_idx >> (sew + 3)) : alu_off_agu;

    // ASSIGNING FIRST SOURCE BASED ON OPCODE TYPE (VX vs VI vs VV)
    always @(*) begin
        // enable ALU if ALU op AND ((VR enabled AND valu.vv) OR valu.vi OR valu.vx)
        case (opcode_mnr_d)
            `IVV_TYPE,
            `FVV_TYPE:
                case (funct6_d)
                    // vid.v
                    6'b010100:  alu_data_in1    = s_ext_imm_d[4:0]; // use s_ext_imm because it already exists
                    default:    alu_data_in1    = vr_rd_data_out_1;  // valu.vv
                endcase
            `MVV_TYPE:
                case (funct6_d[5:3])
                    3'b010: begin
                        case (funct6_d[2:0])
                            // vmv.x.s, vcpop, vfirst
                            3'b000,
                            // vid.v
                            3'b100:     alu_data_in1    = s_ext_imm_d[4:0]; // use s_ext_imm because it already exists
                            default:    alu_data_in1    = vr_rd_data_out_1;  // valu.vv
                        endcase
                    end
                    3'b011:     alu_data_in1 = vm_rd_data_out_1;
                    default:    alu_data_in1 = vr_rd_data_out_1;  // valu.vv
                endcase
            `IVI_TYPE: begin // valu.vi
                case (sew)
                    2'b00:    alu_data_in1  = {DW_B{s_ext_imm_d[7:0]}};
                    2'b01:    alu_data_in1  = {(DW_B>>1){s_ext_imm_d[15:0]}};
                    2'b10:    alu_data_in1  = {(DW_B>>2){s_ext_imm_d[31:0]}};
                    2'b11:    alu_data_in1  = {(DW_B>>2){s_ext_imm_d[63:0]}};
                    default:  alu_data_in1  = {s_ext_imm_d};
                endcase
            end
            `IVX_TYPE,
            `FVF_TYPE,
            `MVX_TYPE: begin // valu.vx
                case (sew)
                    2'b00:    alu_data_in1  = {DW_B{sca_data_in_1_d[7:0]}};
                    2'b01:    alu_data_in1  = {(DW_B>>1){sca_data_in_1_d[15:0]}};
                    2'b10:    alu_data_in1  = {(DW_B>>2){sca_data_in_1_d[31:0]}};
                    2'b11:    alu_data_in1  = {(DW_B>>3){{32{sca_data_in_1_d[31]}},{sca_data_in_1_d[31:0]}}}; // sign-extended
                    default:  alu_data_in1  = {sca_data_in_1_d};
                endcase
            end
            default:  alu_data_in1  = 'h0;
        endcase

        case (funct6_d[5:3])
            // 6'b00111?:  alu_data_in2 = mem_addr_in_d;
            3'b010:  begin
                case({funct6_d[2:0],opcode_mnr_d})
                    {3'b0,`MVV_TYPE}:  alu_data_in2 = s_ext_imm_d[4] ? vm_rd_data_out_2 : vr_rd_data_out_2; // vFirst, vPopc : vmv.x.s                            default
                    {3'b0,`MVX_TYPE}:  alu_data_in2 = lumop_d; // vmv.s.x
                    default:    alu_data_in2 = vr_rd_data_out_2;
                endcase
            end
            3'b011:
                case (opcode_mnr_d)
                    `MVV_TYPE:  alu_data_in2 = vm_rd_data_out_2;
                    default:    alu_data_in2 = vr_rd_data_out_2;
                endcase
            default:  alu_data_in2  = vr_rd_data_out_2;
        endcase
    end

    // --------------------------------------------- AGU INPUT CONTROL ------------------------------------------------------------------
    assign logic_mop = (opcode_mnr == `MVV_TYPE) & (funct6[5:3] == 3'b011 | funct6 == 6'h10);

    // used only for OPIVV, OPFVV, MVV_TYPE (excl VID)
    assign en_vs1   = (opcode_mjr == `OP_INSN & opcode_mnr <= `MVV_TYPE & funct6 != 'h14);

    // used for all ALU (not move or id) and one each of load/store
    // TODO FOR LD/STR: Implement indexed address offsets (the only time vs2 actually used)
    assign en_vs2   = (opcode_mjr == `OP_INSN & opcode_mnr != `CFG_TYPE & funct6 != 'h17 & funct6 != 'h14) | (en_req_mem & mop[0]) | (en_vs3 & mop[0]);//  && ~hold_reg_group;

    // used for ALU
    assign en_vd    = alu_valid_out & ~alu_sca_out;    // write data

    // used only for STORE-FP. OR with vs1, because there is no situation where vs1 and vs3 exist for the same insn
    assign en_vs3       = (opcode_mjr == `ST_INSN);
    assign en_mem_out   = (opcode_mjr_d == `ST_INSN);

    // LOAD
    assign en_req_mem   = (opcode_mjr == `LD_INSN);
    assign en_ld        = ~agu_idle_ld;

    // make single write port!
    assign mem_port_ready_out = wait_mem & agu_idle_wr;

    assign vr_in_en     = ~agu_idle_wr ? vr_wr_en       : vr_ld_en;
    assign vr_in_addr   = ~agu_idle_wr ? vr_wr_addr     : vr_ld_addr;
    assign vr_in_off    = ~agu_idle_wr ? vr_wr_off      : vr_ld_off;
    assign vr_in_data   = ~agu_idle_wr ? vr_wr_data_in  : vr_ld_data_in;

    generate
        if (`MASK_ENABLE) begin
            assign vm_in_en     = alu_valid_out ? vm_wr_en       : vm_ld_en;
            assign vm_in_addr   = alu_valid_out ? alu_addr_out   : vr_ld_addr;
            assign vm_in_off    = alu_valid_out ? alu_off_out    : vr_ld_off;
            assign vm_in_data   = alu_valid_out ? vr_wr_data_in  : vr_ld_data_in;
        end else begin
            assign vm_in_en     = 0;
            assign vm_in_addr   = 0;
            assign vm_in_off    = 0;
            assign vm_in_data   = 0;
        end
    endgenerate

    // ----------------------------------------------- REGFILE CONTROL --------------------------------------------------------------------
    // FIXME only read if mask op?
    wire is_mcmp_op, is_mcmp_op_d, first_or_cpop, first_or_cpop_d;

    assign vr_rd_en_1 = ~agu_idle_rd_1 & ~is_mcmp_op_d; // don't actually read data if it's a mask op!
    assign vr_rd_en_2 = ~agu_idle_rd_2 & ~is_mcmp_op_d; // don't actually read data if it's a mask op!

    always @(posedge clk) begin
        // set "active" if we're reading mask or data -- all this does is enable the alu so it's fine. rename later.
        vr_rd_active_1 <= ~agu_idle_rd_1;
        vr_rd_active_2 <= ~agu_idle_rd_2;
    end

    generate
        if (`MASK_ENABLE) begin
            assign is_mcmp_op = (funct6[5:3] == 3'b011 & opcode_mnr == `MVV_TYPE);
            assign is_mcmp_op_d = (funct6_d[5:3] == 3'b011 & opcode_mnr_d == `MVV_TYPE);
            assign first_or_cpop = (funct6 == 6'h10 & opcode_mnr == `MVV_TYPE);
            assign first_or_cpop_d = (funct6_d == 6'h10 & opcode_mnr_d == `MVV_TYPE);

            assign vm_rd_en_1 = ~agu_idle_rd_1 & (is_mcmp_op | is_mcmp_op_d | ~vm | ~vm_d); // only enable if it's a mask op or masked op!
            assign vm_rd_en_2 = ~agu_idle_rd_2 & (is_mcmp_op | is_mcmp_op_d | first_or_cpop | first_or_cpop_d); // only enable if it's a mask op!

            assign vm_rd_addr_1 = (~vm_d | (~vm  & ~stall)) & ~agu_idle_rd_1 ? 'h0 : vr_rd_addr_1;
            assign vm_rd_off_1  = (~vm_d | (~vm  & ~stall)) & ~agu_idle_rd_1 ? alu_vr_idx_next >> (sew + 3) : vr_rd_off_1;
        end else begin
            assign is_mcmp_op = 0;
            assign is_mcmp_op_d = 0;
            assign vm_rd_en_1 = 0;
            assign vm_rd_en_2 = 0;
        end
    endgenerate

    // ----------------------------------------------------- MEMORY PORT LOGIC ----------------------------------------------------------------

    // memory could just run load/store in parallel with ALU if we implement queue

    // TODO update with mask ld/st
    assign mem_port_valid_out   = rst_n & en_mem_out;
    assign mem_port_data_out    = vr_rd_data_out_1;
    assign mem_port_addr_out    = mem_addr_in_d; // why bother checking validity? thats what the valid signal is for...
    assign mem_port_be_out      = {(MEM_DW_B){1'b1}};

    // LOAD
    assign vr_ld_data_in    = mem_port_data_in;
    assign vr_ld_en         = {DW_B{en_ld & ~wait_mem_msk}};

    generate
        if (`MASK_ENABLE) begin
            assign vm_ld_en         = {DW_B{en_ld & wait_mem_msk}};
        end else begin
            assign vm_ld_en         = 'h0;
        end
    endgenerate

    // --------------------------------------------------- WRITEBACK STAGE LOGIC --------------------------------------------------------------
    assign vr_wr_en         = (~agu_idle_wr & ~alu_mask_out) ? alu_be_out : 'h0;
    assign vr_wr_data_in    = alu_data_out;

    generate
        if (`MASK_ENABLE) begin
            assign vm_wr_en         = alu_valid_out & alu_mask_out ? alu_be_out : 'h0;     // write mask
        end else begin
            assign vm_wr_en         = 0;
        end
    endgenerate

    // -------------------------------------------------- SIGNAL PROPAGATION LOGIC ------------------------------------------------------------
    assign no_bubble = hold_reg_group & (reg_count > 0);

    always @(*) begin
        if (opcode_mnr == `MVV_TYPE && funct6 == 'h10) begin
            case (src_1)
                'h0,
                'h10,
                'h11:       sca_data_in_1 = src_1; // probably zero-extends by default? idk
                default:    sca_data_in_1 = data_in_1_f;
            endcase // vs1

            case (src_2)
                'h0:        sca_data_in_2 = 'h0;
                default:    sca_data_in_2 = data_in_2_f;
            endcase // vs2
        end else begin
            sca_data_in_1 = data_in_1_f;
            sca_data_in_2 = data_in_2_f;
        end
    end

    // Adding byte enable for ALU
    always @(*) begin
        if ((opcode_mnr_d[1]^opcode_mnr_d[0]) & (funct6_d == 'h10)) begin // vmv.s.x (mvx) vmv.x.s (mvv)
            if (alu_vr_idx == 'h0) begin // FIXME this should be moved to agu logic (fix max_reg and max_off to 0)
                case (sew)
                    'h0: alu_req_be = 'h1;
                    'h1: alu_req_be = 'h3;
                    'h2: alu_req_be = 'hF;
                    'h3: alu_req_be = 'hFF;
                    default: alu_req_be = 'hFF;
                endcase
            end else begin
                alu_req_be = 'h0;
            end
        end else begin // FIXME -- how do we use AVL when it's a variable??
            // Next mask will always come from v0, we really only need to read and write masks for mask manipulation instructions
            alu_req_be = gen_avl_be & vmask_ext; // vm=1 is unmasked
        end
    end

    generate_be #(.DATA_WIDTH(DATA_WIDTH), .DW_B(DW_B), .AVL_WIDTH(VLEN_B_BITS)) gen_be_alu (.avl   (avl), .sew(sew), .reg_count(widen_en_d ? alu_vr_idx[11:1] : alu_vr_idx[10:0]), .avl_be(gen_avl_be));


    always @(posedge clk) begin
        if(~rst_n) begin
            opcode_mjr_d    <= 'h0;
            opcode_mnr_d    <= 'h0;
            dest_d          <= 'h0;
            lumop_d         <= 'h0;

            funct6_d        <= 'h0;
            vm_d            <= 'b1; // unmasked by default
            ld_valid        <= 'h0;

            sca_data_in_1_d <= 'h0;
            sca_data_in_2_d <= 'h0;
            mem_addr_in_d   <= 'b0;
            vxrm_in_d       <= 'b0;

            out_ack_e       <= 'b0;
            out_ack_m       <= 'b0;

            dest_m          <= 'h0;

            lumop_m         <= 'h0;
        end else begin
            // all stalling should happen here
            opcode_mjr_d    <= ~stall ? opcode_mjr  : (no_bubble ? opcode_mjr_d : 'h0);
            opcode_mnr_d    <= ~stall ? opcode_mnr  : (no_bubble ? opcode_mnr_d : 'h0);
            dest_d          <= ~stall ? dest        : (no_bubble ? dest_d       : 'h0);

            lumop_d         <= ~stall ? src_2       : (no_bubble ? lumop_d      : 'h0);
            mop_d           <= ~stall ? mop         : (no_bubble ? mop_d        : 'h0);
            funct6_d        <= ~stall ? funct6      : (no_bubble ? funct6_d     : 'h0);
            vm_d            <= ~stall ? vm          : (no_bubble ? vm_d         : 'b1);

            sca_data_in_1_d <= ~stall ? sca_data_in_1 : (no_bubble ? sca_data_in_1_d : 'h0);
            sca_data_in_2_d <= ~stall ? sca_data_in_2 : (no_bubble ? sca_data_in_2_d : 'h0);

            vxrm_in_d       <= ~stall ? vxrm_in_f   : (no_bubble ? vxrm_in_d    : 'h0);

            widen_en_d      <= ~stall ? widen_en    : (no_bubble ? widen_en_d   : 'h0);

            mem_port_req_out<= ~stall ? en_req_mem : (no_bubble & mem_port_req_out);
            mem_addr_in_d   <= ~stall ? data_in_1_f : (no_bubble ? (mem_addr_in_d + DW_B) : 'h0);

            out_ack_e       <= (alu_valid_out & alu_resp_end);
            out_data_e      <= (alu_sca_out ? alu_data_out[VEX_DATA_WIDTH-1:0] : 'h0);
            out_ack_m       <= (mem_port_valid_in & mem_port_done_ld) | (mem_port_done_st);

            // hold these values until we get a response
            opcode_mjr_m    <= wait_mem & ~mem_port_done_ld ? opcode_mjr_m : opcode_mjr_d;
            dest_m          <= wait_mem ? dest_m    : dest_d;

            lumop_m         <= wait_mem ? lumop_m   : lumop_d;
            mop_m           <= wait_mem ? mop_m     : mop_d;
            ld_valid        <= wait_mem;
            wait_mem        <= wait_mem ? ~mem_port_done_ld : (opcode_mjr_m == `LD_INSN);
            wait_mem_msk    <= wait_mem_msk ? ~mem_port_done_ld : ((opcode_mjr_m == `LD_INSN) & lumop_m == 5'hB & mop_m == 'h0);

            vexrv_data_out  <= (opcode_mjr_d == `OP_INSN & opcode_mnr_d == `CFG_TYPE & new_vl) ? avl : out_data_e;
            vexrv_valid_out <= out_ack_e | out_ack_m | (opcode_mjr_d == `OP_INSN & opcode_mnr_d == `CFG_TYPE & new_vl);
        end // end else
    end

endmodule

module generate_be #(
    parameter AVL_WIDTH     = 12,
    parameter DATA_WIDTH    = 64,
    parameter DW_B          = DATA_WIDTH/8,
    parameter DW_B_BITS     = 3
    ) (
    input   [AVL_WIDTH-1:0] avl,
    input   [          1:0] sew,
    input   [         10:0] reg_count,
    output  [     DW_B-1:0] avl_be
    );

    wire [DW_B-1:0] avl_be_sew   [0:3];

    parameter REP_BITS = 1;

    genvar i, j;

    // Generate mask byte enable based on SEW and current index in vector
    generate
        for (j = 0; j < 4; j = j + 1) begin
            for (i = 0; i < DW_B >> j; i = i + 1) begin
                assign avl_be_sew[j][i*(REP_BITS<<j) +: (REP_BITS<<j)] = {(REP_BITS<<j){(((reg_count*DW_B) >> j) + i) < avl}};
            end
        end
    endgenerate

    assign avl_be = avl_be_sew[sew];
endmodule

// FIXME make generic if possible
module extract_mask #(
    parameter DATA_WIDTH    = 64,
    parameter DW_B          = DATA_WIDTH/8,
    parameter DW_B_BITS     = 3
    ) (
    input   [    DW_B-1:0]  vmask_in,
    input   [         1:0]  sew,
    input   [         2:0]  reg_off,
    input                   en,
    output  [    DW_B-1:0]  vmask_out
    );

    wire [DW_B-1:0] vmask_sew   [0:3];

    // Generate mask byte enable based on SEW and current index in vector
    assign vmask_sew[0] = vmask_in;
    assign vmask_sew[1] = {{2{vmask_in[reg_off + 3]}},{2{vmask_in[reg_off + 2]}},{2{vmask_in[reg_off + 1]}},{2{vmask_in[reg_off]}}};
    assign vmask_sew[2] = {{4{vmask_in[reg_off + 1]}},{4{vmask_in[reg_off]}}};
    assign vmask_sew[3] = {8{vmask_in[reg_off]}};
    // todo case stmt
    assign vmask_out = en ? vmask_sew[sew] : {DW_B{1'b1}};
endmodule
