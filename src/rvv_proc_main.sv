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

`define AVL_WIDTH 64

module rvv_proc_main #(
    parameter VLEN              = 128,              // vector length in bits
    parameter XLEN              = 32,               // not sure, data width maybe?
    parameter NUM_VEC           = 32,               // number of available vector registers
    parameter INSN_WIDTH        = 32,               // width of a single instruction
    parameter DATA_WIDTH        = 64,
    parameter DW_B              = DATA_WIDTH>>3,    // DATA_WIDTH in bytes
    parameter ADDR_WIDTH        = 5,                //$clog2(NUM_VEC)
    parameter MEM_ADDR_WIDTH    = 32,               // We need to get this from VexRiscV
    parameter MEM_DATA_WIDTH    = 64,
    parameter MEM_DW_B          = MEM_DATA_WIDTH>>3,
    parameter VEX_DATA_WIDTH    = 32,
    parameter OFF_BITS          = 8                 // max value is 256 (2048/64)
) (
    input                               clk,
    input                               rst_n,
    input       [    INSN_WIDTH-1:0]    insn_in, // make this a queue I guess?
    input                               insn_valid,
    input       [    DATA_WIDTH-1:0]    mem_port_data_in,
    input                               mem_port_valid_in,
    input                               mem_port_done_ld,
    input                               mem_port_done_st,
    input       [VEX_DATA_WIDTH-1:0]    vexrv_data_in_1,    // memory address from load/store command
    input       [VEX_DATA_WIDTH-1:0]    vexrv_data_in_2,
    output      [MEM_DATA_WIDTH-1:0]    mem_port_data_out,
    output      [MEM_ADDR_WIDTH-1:0]    mem_port_addr_out,
    output reg                          mem_port_req_out,       // signal dicating request vs write I guess?
    output                              mem_port_valid_out,
    output      [      MEM_DW_B-1:0]    mem_port_be_out,
    output reg                          mem_port_start_out,
    output                              proc_rdy,
    output reg  [VEX_DATA_WIDTH-1:0]    vexrv_data_out,   // in theory anything writing to a scalar register should already know the dest register right?
    output reg                          vexrv_valid_out
    // TODO: add register config outputs?
);
    wire  [          DW_B-1:0]  vr_rd_en_1;
    wire  [          DW_B-1:0]  vr_rd_en_2;
    wire  [          DW_B-1:0]  vr_wr_en;
    wire  [          DW_B-1:0]  vr_ld_en;
    wire  [          DW_B-1:0]  vr_st_en;
    
    wire  [          DW_B-1:0]  vmask_ext;
    reg   [        VLEN/8-1:0]  vm_0; // The currently set mask based on the mask ops before

    wire  [          DW_B-1:0]  vm_rd_en_1;
    wire  [          DW_B-1:0]  vm_rd_en_2;
    wire  [          DW_B-1:0]  vm_wr_en;
    wire  [          DW_B-1:0]  vm_ld_en;
    wire  [          DW_B-1:0]  vm_st_en;

    reg                         vr_rd_active_1;
    reg                         vr_rd_active_2;

    reg                         vm_rd_active_1;
    reg                         vm_rd_active_2;

    wire  [    ADDR_WIDTH-1:0]  vr_rd_addr_1;
    wire  [    ADDR_WIDTH-1:0]  vr_rd_addr_2;
    wire  [    ADDR_WIDTH-1:0]  vr_wr_addr;
    wire  [    ADDR_WIDTH-1:0]  vr_ld_addr;
    wire  [    ADDR_WIDTH-1:0]  vr_st_addr;

    wire  [      OFF_BITS-1:0]  vr_rd_off_1;
    wire  [      OFF_BITS-1:0]  vr_rd_off_2;
    wire  [      OFF_BITS-1:0]  vr_wr_off;
    wire  [      OFF_BITS-1:0]  vr_ld_off;
    wire  [      OFF_BITS-1:0]  vr_st_off;

    wire  [    ADDR_WIDTH-1:0]  vm_rd_addr_1;
    wire  [    ADDR_WIDTH-1:0]  vm_rd_addr_2;
    wire  [    ADDR_WIDTH-1:0]  vm_wr_addr;
    wire  [    ADDR_WIDTH-1:0]  vm_ld_addr;
    wire  [    ADDR_WIDTH-1:0]  vm_st_addr;

    wire  [      OFF_BITS-1:0]  vm_rd_off_1;
    wire  [      OFF_BITS-1:0]  vm_rd_off_2;
    wire  [      OFF_BITS-1:0]  vm_wr_off;
    wire  [      OFF_BITS-1:0]  vm_ld_off;
    wire  [      OFF_BITS-1:0]  vm_st_off;

    wire  [    DATA_WIDTH-1:0]  vr_wr_data_in;
    wire  [    DATA_WIDTH-1:0]  vr_rd_data_out_1;
    wire  [    DATA_WIDTH-1:0]  vr_rd_data_out_2;
    wire  [    DATA_WIDTH-1:0]  vr_ld_data_in;
    wire  [    DATA_WIDTH-1:0]  vr_st_data_out;

    wire  [    DATA_WIDTH-1:0]  vm_wr_data_in;
    wire  [    DATA_WIDTH-1:0]  vm_rd_data_out_1;
    wire  [    DATA_WIDTH-1:0]  vm_rd_data_out_2; 
    wire  [    DATA_WIDTH-1:0]  vm_ld_data_in;
    wire  [    DATA_WIDTH-1:0]  vm_st_data_out;

    reg   [    INSN_WIDTH-1:0]  insn_in_f;
    reg                         insn_valid_f;
    reg   [VEX_DATA_WIDTH-1:0]  data_in_1_f;
    reg   [VEX_DATA_WIDTH-1:0]  data_in_2_f;

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
    // reg   [               4:0]  src_1_d;
    // reg   [               4:0]  src_2_d;
    reg   [               4:0]  dest_d;    // rd, vd, or vs3 -- TODO make better name lol
    reg   [               5:0]  funct6_d;
    reg                         vm_d;
    reg   [VEX_DATA_WIDTH-1:0]  avl_d;
    reg   [VEX_DATA_WIDTH-1:0]  sca_data_in_1_d;
    reg   [VEX_DATA_WIDTH-1:0]  sca_data_in_2_d;


    // reg   [               6:0]  opcode_mjr_e;
    // reg   [               2:0]  opcode_mnr_e;
    // reg   [               4:0]  src_1_e;
    // reg   [               4:0]  src_2_e;
    // reg   [               4:0]  dest_e;   // rd, vd, or vs3 -- TODO make better name lol
    // reg   [               5:0]  funct6_e;
    // reg                         vm_e;
    // reg   [VEX_DATA_WIDTH-1:0]  sca_data_in_1_e;
    // reg   [VEX_DATA_WIDTH-1:0]  sca_data_in_2_e;

    reg   [               6:0]  opcode_mjr_m;
    // reg   [               2:0]  opcode_mnr_m;
    // reg   [               4:0]  src_1_m;
    // reg   [               4:0]  src_2_m;
    reg   [               4:0]  dest_m;    // rd, vd, or vs3 -- TODO make better name lol
    // reg   [               5:0]  funct6_m;
    // reg   [               4:0]  prev_ld_reg;

    // reg   [               6:0]  opcode_mjr_w;
    // reg   [               2:0]  opcode_mnr_w;
    // reg   [               4:0]  src_1_w;
    // reg   [               4:0]  src_2_w;
    // reg   [               4:0]  dest_w;    // rd, vd, or vs3 -- TODO make better name lol
    // reg   [               5:0]  funct6_w;

    reg                         out_ack_d;
    reg                         out_ack_e;
    reg                         out_ack_m;

    // CONFIG VALUES -- config unit flops them, these are just connector wires
    wire  [VEX_DATA_WIDTH-1:0]  avl; // Application Vector Length (vlen effective)
    wire                        new_vl;

    // VTYPE values
    wire  [               2:0]  sew;
    wire  [               2:0]  vlmul;
    wire  [          XLEN-1:0]  vtype;
    wire                        vma;
    wire                        vta;
    wire                        vill;

    wire  [          XLEN-1:0]  vtype_nxt;
    wire  [               1:0]  avl_set;
    reg   [ VLEN/DATA_WIDTH:0]  reg_count;

    wire                        agu_idle_rd_1;
    wire                        agu_idle_rd_2;
    wire                        agu_idle_wr;
    wire                        agu_idle_ld;
    wire                        agu_idle_st;

    wire                        alu_enable;
    wire  [               2:0]  alu_req_sew;
    wire  [VEX_DATA_WIDTH-1:0]  alu_req_avl;
    
    reg   [    DATA_WIDTH-1:0]  s_ext_imm;
    reg   [    DATA_WIDTH-1:0]  s_ext_imm_d;
    // reg   [    DATA_WIDTH-1:0]  s_ext_imm_e;

    reg   [    DATA_WIDTH-1:0]  alu_data_in1;
    reg   [    DATA_WIDTH-1:0]  alu_data_in2;
    wire  [    DATA_WIDTH-1:0]  alu_data_out;

    wire  [    ADDR_WIDTH-1:0]  alu_addr_out;
    wire  [      OFF_BITS-1:0]  alu_req_off;
    reg   [      OFF_BITS-1:0]  alu_off_agu;
    wire  [      OFF_BITS-1:0]  alu_off_out;
    wire                        alu_valid_out;
    wire  [VEX_DATA_WIDTH-1:0]  alu_avl_out;
    wire                        alu_mask_out;
    reg   [          DW_B-1:0]  alu_req_be;
    wire  [          DW_B-1:0]  alu_be_out;
    wire  [ VLEN/DATA_WIDTH:0]  alu_vr_idx;

    wire                        hold_reg_group;
    reg                         vec_haz         [0:NUM_VEC-1]; // use this to indicate that vec needs bubble????
    wire                        vec_haz_set     [0:NUM_VEC-1]; // use this to indicate that vec needs bubble????
    wire                        vec_haz_clr     [0:NUM_VEC-1]; // use this to indicate that vec needs bubble????
    wire                        no_bubble;

    reg   [    ADDR_WIDTH-1:0]  ld_addr;
    reg   [    DATA_WIDTH-1:0]  ld_data_in;
    reg                         ld_valid;

    // Detect hazards for operands
    wire                        haz_src1;
    wire                        haz_src2;
    wire                        haz_st;
    wire                        haz_ld;

    wire                        haz_new_src1;
    wire                        haz_new_src2;
    wire                        haz_new_st;
    wire                        haz_new_ld;

    wire                        logic_mop;

    wire                        agu_addr_start_rd_1,    agu_addr_start_rd_2,    agu_addr_start_wr,  agu_addr_start_ld,  agu_addr_start_st;
    wire                        agu_addr_end_rd_1,      agu_addr_end_rd_2,      agu_addr_end_wr,    agu_addr_end_ld,    agu_addr_end_st;
    reg                         alu_req_start,  alu_req_end;
    wire                        alu_resp_start, alu_resp_end;

    wire  [      OFF_BITS-1:0]  avl_max_off;

    genvar i,j;

    //   wire alu_req_ready;
    //   wire alu_req_vl_out;

    // -------------------------------------------------- CONNECTED MODULES ---------------------------------------------------------------------------------

   

    insn_decoder #(.INSN_WIDTH(INSN_WIDTH)) id (.clk(clk), .rst_n(rst_n), .insn_in(insn_in_f), .opcode_mjr(opcode_mjr), .opcode_mnr(opcode_mnr), .dest(dest), .src_1(src_1), .src_2(src_2),
        .width(width), .mop(mop), .mew(mew), .nf(nf), .vtype_11(vtype_11), .vtype_10(vtype_10), .vm(vm), .funct6(funct6), .cfg_type(cfg_type));

    // TODO: figure out how to make this single cycle, so we can fully pipeline lol
    addr_gen_unit #(.ADDR_WIDTH(ADDR_WIDTH)) agu_src1 (.clk(clk), .rst_n(rst_n), .en(en_vs1 & ~stall),  .vlmul({3{~logic_mop}}&vlmul),    .addr_in(src_1),        .addr_out(vr_rd_addr_1), .max_off_in(avl_max_off),.off_out(vr_rd_off_1), .idle(agu_idle_rd_1),   .addr_start(agu_addr_start_rd_1),   .addr_end(agu_addr_end_rd_1));
    addr_gen_unit #(.ADDR_WIDTH(ADDR_WIDTH)) agu_src2 (.clk(clk), .rst_n(rst_n), .en(en_vs2 & ~stall),  .vlmul({3{~logic_mop}}&vlmul),    .addr_in(src_2),        .addr_out(vr_rd_addr_2), .max_off_in(avl_max_off),.off_out(vr_rd_off_2), .idle(agu_idle_rd_2),   .addr_start(agu_addr_start_rd_2),   .addr_end(agu_addr_end_rd_2));
    addr_gen_unit #(.ADDR_WIDTH(ADDR_WIDTH)) agu_dest (.clk(clk), .rst_n(rst_n), .en(en_vd),            .vlmul({3{~alu_mask_out}}&vlmul), .addr_in(alu_addr_out), .addr_out(vr_wr_addr),   .max_off_in(avl_max_off),.off_out(vr_wr_off),   .idle(agu_idle_wr),     .addr_start(agu_addr_start_wr),     .addr_end(agu_addr_end_wr));

    addr_gen_unit #(.ADDR_WIDTH(ADDR_WIDTH)) agu_st (.clk(clk), .rst_n(rst_n), .en(en_vs3&~stall),              .vlmul(vlmul), .addr_in(dest),  .addr_out(vr_st_addr), .max_off_in(avl_max_off), .off_out(vr_st_off),.idle(agu_idle_st), .addr_start(agu_addr_start_st), .addr_end(agu_addr_end_st));
    addr_gen_unit #(.ADDR_WIDTH(ADDR_WIDTH)) agu_ld (.clk(clk), .rst_n(rst_n), .en(ld_valid&mem_port_valid_in), .vlmul(vlmul), .addr_in(dest_m),.addr_out(vr_ld_addr), .max_off_in(avl_max_off), .off_out(vr_ld_off),.idle(agu_idle_ld), .addr_start(agu_addr_start_ld), .addr_end(agu_addr_end_ld));

    // TODO: add normal regfile? connect to external one? what do here
    vec_regfile #(.VLEN(VLEN), .DATA_WIDTH(DATA_WIDTH), .ADDR_WIDTH(ADDR_WIDTH), .OFF_BITS(OFF_BITS)) vr (.clk(clk),.rst_n(rst_n),
                .rd_en_1(vr_rd_en_1),       .rd_en_2(vr_rd_en_2),       .wr_en(vr_wr_en),       .ld_en(vr_ld_en),       .st_en(vr_st_en),
                .rd_addr_1(vr_rd_addr_1),   .rd_addr_2(vr_rd_addr_2),   .wr_addr(vr_wr_addr),   .ld_addr(vr_ld_addr),   .st_addr(vr_st_addr),
                .rd_off_1(vr_rd_off_1),     .rd_off_2(vr_rd_off_2),     .wr_off(vr_wr_off),     .ld_off(vr_ld_off),     .st_off(vr_st_off),
                .wr_data_in(vr_wr_data_in),.ld_data_in(vr_ld_data_in),.st_data_out(vr_st_data_out),.rd_data_out_1(vr_rd_data_out_1),.rd_data_out_2(vr_rd_data_out_2));

    mask_regfile #(.VLEN(VLEN), .DATA_WIDTH(DATA_WIDTH), .ADDR_WIDTH(ADDR_WIDTH), .OFF_BITS(OFF_BITS)) vmr (.clk(clk),.rst_n(rst_n),
                .rd_en_1(vm_rd_en_1),.rd_en_2(vm_rd_en_2),.wr_en(vm_wr_en),.ld_en(vm_ld_en),.st_en(vm_st_en),
                .rd_addr_1(vr_rd_addr_1),.rd_addr_2(vr_rd_addr_2),.wr_addr(vm_wr_addr),.ld_addr(vm_ld_addr),.st_addr(vr_st_addr),
                .rd_off_1(vr_rd_off_1),.rd_off_2(vr_rd_off_2),.wr_off(vm_wr_off),.ld_off(vm_ld_off),.st_off(vr_st_off),
                .wr_data_in(vm_wr_data_in),.ld_data_in(vm_ld_data_in),.st_data_out(vm_st_data_out),.rd_data_out_1(vm_rd_data_out_1),.rd_data_out_2(vm_rd_data_out_2));
  
    cfg_unit #(.XLEN(XLEN), .VLEN(VLEN)) cfg_unit (.clk(clk), .rst_n(rst_n), .en(cfg_en), .vtype_nxt(vtype_nxt), .cfg_type(cfg_type), .src_1(src_1), .avl_set(avl_set),
        .avl_new(data_in_1_f), .avl(avl), .sew(sew), .vlmul(vlmul), .vma(vma), .vta(vta), .vill(vill), .new_vl(new_vl));

    extract_mask #(.VLEN(VLEN), .DATA_WIDTH(DATA_WIDTH)) vm_alu (.clk(clk), .rst_n(rst_n), .vmask_in(vm_0), .sew(sew), .reg_count(alu_vr_idx), .vmask_out(vmask_ext));

    // TODO: update to use active low reset lol
    vALU #(.REQ_DATA_WIDTH(DATA_WIDTH), .RESP_DATA_WIDTH(DATA_WIDTH), .REQ_ADDR_WIDTH(ADDR_WIDTH), .REQ_VL_WIDTH(8))
            alu (.clk(clk), .rst(~rst_n), .req_mask(vm_d), .req_be(alu_req_be), .req_vr_idx(alu_vr_idx), .req_start(alu_req_start), .req_end(alu_req_end),
        .req_valid(alu_enable), .req_op_mnr(opcode_mnr_d), .req_func_id(funct6_d), .req_sew(sew[1:0]), .req_data0(alu_data_in1), .req_data1(alu_data_in2), .req_addr(dest_d), .req_off(alu_req_off),
        .resp_valid(alu_valid_out), .resp_data(alu_data_out), .req_addr_out(alu_addr_out), .req_vl(alu_req_avl), .req_vl_out(alu_avl_out), .req_mask_out(alu_mask_out), .req_be_out(alu_be_out),
        .resp_start(alu_resp_start), .resp_end(alu_resp_end), .resp_off(alu_off_out));
    //  MISSING PORT CONNECTIONS:
    //     output                             req_ready   ,
    // );

    // ------------------------- BEGIN DEBUG --------------------------
    // Read vector sources
    // TODO: add mask read logic

    // assign haz_24_new        = vec_haz_set[24];
    // assign haz_24_clr        = vec_haz_clr[24];
    // assign haz_24            = vec_haz[24];
    // assign haz_25_new        = vec_haz_set[25];
    // assign haz_25_clr        = vec_haz_clr[25];
    // assign haz_25            = vec_haz[25];
    // assign haz_26_new        = vec_haz_set[26];
    // assign haz_26_clr        = vec_haz_clr[26];
    // assign haz_26            = vec_haz[26];
    // assign haz_27_new        = vec_haz_set[27];
    // assign haz_27_clr        = vec_haz_clr[27];
    // assign haz_27            = vec_haz[27];

    // ------------------------- END DEBUG --------------------------

    // -------------------------------------------------- FETCH AND HAZARD DETECTION -----------------------------------------------------------------------
    // need to stall for register groupings
    // TODO: stall for hazards within 1 cycle -- we are at 2

    always @(posedge clk) begin
        insn_in_f       <= {INSN_WIDTH{rst_n}} & (stall ? insn_in_f : (insn_valid ? insn_in : 'h0));
        insn_valid_f    <= rst_n & (stall ? insn_valid_f : insn_valid);
        data_in_1_f     <= {VEX_DATA_WIDTH{rst_n}} & (stall ? data_in_1_f : (insn_valid ? vexrv_data_in_1 : 'h0));
        data_in_2_f     <= {VEX_DATA_WIDTH{rst_n}} & (stall ? data_in_2_f : (insn_valid ? vexrv_data_in_2 : 'h0));
    end

    // FIXME separate into "clear hazard" and "set hazard" logic so we can check hazards more easily lol
    // FIXME WRITE AFTER WRITE MEANS HAZARD MIGHT GET FALSELY CLEARED
    // Hazard COUNT? IS THAT TOO MUCH?
    generate
        for (i = 0; i < NUM_VEC; i=i+1) begin
            // we shouldn't set the hazard unless we are actually processing a new instruction I think
            assign vec_haz_set[i] = (~stall & dest === i) & ((opcode_mjr === `OP_INSN & opcode_mnr !== `CFG_TYPE) | en_req_mem);
            assign vec_haz_clr[i] = (dest_m === i & en_ld & mem_port_done_ld) |
                                    (alu_addr_out === i & alu_valid_out & alu_resp_end); // right now we write to vm multiple times -- this should change to just generate one result and output the whole thing at once
            always @(posedge clk) begin
                // set high if incoming vector is going to overwrite the destination, or it has a hazard that isn't being cleared this cycle
                // else, set low
                vec_haz[i] <= rst_n & (vec_haz_set[i] | vec_haz[i]) & ~vec_haz_clr[i];
            end
        end
    endgenerate
  
    // FIXME this logic wouldn't work for v1 = v1 + v1
    assign haz_waw          = vec_haz[dest] & (en_vs1 | en_vs2 | en_req_mem);
    assign haz_src1         = vec_haz[src_1] & en_vs1;
    assign haz_src2         = vec_haz[src_2] & en_vs2;
    assign haz_st           = vec_haz[dest] & en_vs3;

    // Load doesn't really ever have hazards, since it just writes to a reg and that should be in order! Right?
    // WRONG -- CONSIDER CASE WHERE insn in the ALU path has the same dest addr. We *should* preserve write order there.

    // Just stall for WAW hazards for now
    assign stall    = ~rst_n | (hold_reg_group & reg_count > 0) | haz_src1 | haz_src2 | haz_st | haz_waw;// | haz_ld;

    assign proc_rdy = ~stall;
    // ----------------------------------------- VTYPE CONTROL SIGNALS -------------------------------------------------------------------

    // VLEN AND VSEW
    // TODO: store AVL value in register
    assign vtype_nxt = cfg_type[1] ? {12'h0, vtype_10} : {11'h0, vtype_11};
    assign cfg_en    = (opcode_mjr === `OP_INSN && opcode_mnr === `CFG_TYPE);
    assign avl_set   = {(dest === 'h0),(src_1 === 'h0)}; // determines if rd and rs1 are non-zero, as AVL setting depends on this
    assign avl_max_off = avl/DW_B - 1;

    // ---------------------------------------- ALU CONTROL --------------------------------------------------------------------------

    // hold values steady while waiting for multiple register groupings
    assign hold_reg_group   = rst_n & ((reg_count > 0) | (reg_count === 0 & (en_vs3 | en_req_mem | (opcode_mjr === `OP_INSN & opcode_mnr !== `CFG_TYPE & ~(logic_mop))) & vlmul > 0));
    // hold if we are starting a reg group or currently processing one

    // SIGN-EXTENDED IMMEDIATE FOR ALU
    always @(*) begin
        case (sew)
            3'h0:     s_ext_imm = {{(DATA_WIDTH-8){1'b0}}, {3{src_1[4]}}, src_1};
            3'h1:     s_ext_imm = {{(DATA_WIDTH-16){1'b0}}, {11{src_1[4]}}, src_1};
            3'h2:     s_ext_imm = {{(DATA_WIDTH-32){1'b0}}, {27{src_1[4]}}, src_1};
            3'h3:     s_ext_imm = {{(DATA_WIDTH-64){1'b0}}, {59{src_1[4]}}, src_1};
            default:  s_ext_imm = 3'h0;
        endcase
    end

    always @(posedge clk) begin
        if (~rst_n) begin
            reg_count   <= 'h0;
            s_ext_imm_d <= 'h0;
        end else begin
            reg_count   <= (reg_count > 0)    ? reg_count - 1 : (hold_reg_group ? (('b1 << vlmul)*(avl/DW_B) - 1) : 0);

            s_ext_imm_d <= (reg_count === 0 && opcode_mjr === `OP_INSN) ? s_ext_imm : s_ext_imm_d; // latch value for register groupings
        end
    end


    // ALU INPUTS
    always @(posedge clk) begin
        alu_req_start   <= agu_addr_start_rd_1 | agu_addr_start_rd_2 | ((opcode_mjr=== `OP_INSN) & (opcode_mnr === `IVI_TYPE | (opcode_mnr === `MVV_TYPE & funct6 === 'h14)) & (reg_count === 0));
        alu_req_end     <= agu_addr_end_rd_1 | agu_addr_end_rd_2 | ((opcode_mjr_d === `OP_INSN) & (opcode_mnr_d === `IVI_TYPE | (opcode_mnr_d === `MVV_TYPE & funct6_d === 'h14)) & (reg_count === 1));

        alu_off_agu     <= vr_rd_off_1;
    end

    assign alu_req_sew      = sew;
    assign alu_req_avl      = avl;
    assign alu_vr_idx       = ((1'b1 << vlmul)*(avl/DW_B) - 1) - reg_count;

    assign alu_enable   = (opcode_mjr_d === `OP_INSN) & (  ((vr_rd_active_1 | vr_rd_active_2) & (opcode_mnr_d === `IVV_TYPE | opcode_mnr_d === `MVV_TYPE)) |
                                                            (opcode_mnr_d === `IVI_TYPE) | (opcode_mnr_d === `IVX_TYPE) | (opcode_mnr_d === `MVX_TYPE)   |
                                                            (opcode_mnr_d === `MVV_TYPE & funct6_d === 'h14));

    assign alu_req_off  = (funct6_d[5:3] == 3'b011) & (opcode_mnr_d === 3'h0 | opcode_mnr_d === 3'h3 | opcode_mnr_d === 3'h4) ? alu_vr_idx/(1'b1 << vlmul) : alu_off_agu;

    // ASSIGNING FIRST SOURCE BASED ON OPCODE TYPE (VX vs VI vs VV)
    always @(*) begin
        // enable ALU if ALU op AND ((VR enabled AND valu.vv) OR valu.vi OR valu.vx)
        case (opcode_mnr_d)
            3'h0,
            3'h1:
                case (funct6_d)
                    // vid.v
                    6'b010100:  alu_data_in1    = {{(DATA_WIDTH-5){1'b0}},s_ext_imm_d[4:0]}; // use s_ext_imm because it already exists
                    default:    alu_data_in1    = vr_rd_data_out_1;  // valu.vv
                endcase
            3'h2:
                case (funct6_d[5:3])
                    3'b010: begin
                        case (funct6_d[2:0])
                            // vid.v
                            3'b100:     alu_data_in1    = {{(DATA_WIDTH-5){1'b0}},s_ext_imm_d[4:0]}; // use s_ext_imm because it already exists
                            default:    alu_data_in1    = vr_rd_data_out_1;  // valu.vv
                        endcase
                    end
                    3'b011:     alu_data_in1 = vm_rd_data_out_1;
                    default:    alu_data_in1 = vr_rd_data_out_1;  // valu.vv
                endcase
            3'h3: begin // valu.vi
                case (alu_req_sew)
                    2'b00:    alu_data_in1  = {DW_B{s_ext_imm_d[7:0]}};
                    2'b01:    alu_data_in1  = {(DW_B/2){s_ext_imm_d[15:0]}};
                    2'b10:    alu_data_in1  = {(DW_B/4){s_ext_imm_d[31:0]}};
                    2'b11:    alu_data_in1  = {(DW_B/8){s_ext_imm_d[63:0]}};
                    default:  alu_data_in1  = {s_ext_imm_d};
                endcase
            end
            3'h4,
            3'h5,
            3'h6: begin // valu.vx
                case (alu_req_sew)
                    2'b00:    alu_data_in1  = {DW_B{sca_data_in_1_d[7:0]}};
                    2'b01:    alu_data_in1  = {(DW_B/2){sca_data_in_1_d[15:0]}};
                    2'b10:    alu_data_in1  = {(DW_B/4){sca_data_in_1_d[31:0]}};
                    2'b11:    alu_data_in1  = {(DW_B/8){{32{sca_data_in_1_d[31]}},{sca_data_in_1_d[31:0]}}};
                    default:  alu_data_in1  = {sca_data_in_1_d};
                endcase
            end
            default:  alu_data_in1  = 'hX;
        endcase

        if (funct6_d[5:3] === 3'b011 & opcode_mnr_d === `MVV_TYPE) begin
            alu_data_in2 = vm_rd_data_out_2;    // mask logic function
        end else begin
            alu_data_in2 = vr_rd_data_out_2;
        end
    end

    // --------------------------------------------- AGU INPUT CONTROL ------------------------------------------------------------------
    assign logic_mop = (opcode_mnr === `MVV_TYPE) & (funct6[5:3] === 3'b011);
    
    // used only for OPIVV, OPFVV, MVV_TYPE (excl VID)
    assign en_vs1   = (opcode_mjr === `OP_INSN & opcode_mnr <= 3'h2 & funct6 !== 'h14);// && ~hold_reg_group;

    // used for all ALU (not move or id) and one each of load/store
    // TODO FOR LD/STR: Implement indexed address offsets (the only time vs2 actually used)
    assign en_vs2   = (opcode_mjr === `OP_INSN & opcode_mnr !== `CFG_TYPE & funct6 !== 'h17 & funct6 !== 'h14) | (en_req_mem & mop[0]) | (en_vs3 & mop[0]);//  && ~hold_reg_group;

    // used for ALU
    assign en_vd    = alu_valid_out;// & ~alu_mask_out;    // write data

    // used only for STORE-FP. OR with vs1, because there is no situation where vs1 and vs3 exist for the same insn
    assign en_vs3       = (opcode_mjr === `ST_INSN);
    assign en_mem_out   = (opcode_mjr_d === `ST_INSN);

    // LOAD
    assign en_req_mem   = (opcode_mjr === `LD_INSN);
    assign en_ld        = ~agu_idle_ld;


    // ----------------------------------------------- REGFILE CONTROL --------------------------------------------------------------------
    assign vr_rd_en_1 = {DW_B{~agu_idle_rd_1}}; // & ~(funct6[5:3] == 3'b011 & opcode_mnr == `MVV_TYPE)}}; // don't actually read data if it's a mask op!
    assign vm_rd_en_1 = {DW_B{~agu_idle_rd_1}}; // & (funct6[5:3] == 3'b011 & opcode_mnr == `MVV_TYPE)}}; // only enable if it's a mask op!

    assign vr_rd_en_2 = {DW_B{~agu_idle_rd_2}};//& ~(funct6[5:3] == 3'b011 & opcode_mnr == `MVV_TYPE)}}; // don't actually read data if it's a mask op!
    assign vm_rd_en_2 = {DW_B{~agu_idle_rd_2}};// & (funct6[5:3] == 3'b011 & opcode_mnr == `MVV_TYPE)}}; // only enable if it's a mask op!

    // TODO merge vm and vr and just add another port for the mask probably (simplifies logic!)

    assign vm_rd_addr_1 = src_1;
    assign vm_rd_addr_2 = src_2;
    assign vm_wr_addr   = alu_addr_out;
    assign vm_wr_off    = alu_off_out;

    always @(posedge clk) begin
        // set "active" if we're reading mask or data -- all this does is enable the alu so it's fine. rename later.
        vr_rd_active_1 <= rst_n & (|vr_rd_en_1 | |vm_rd_en_1);
        vr_rd_active_2 <= rst_n & (|vr_rd_en_2 | |vm_rd_en_2);
    end

    // TODO: and with mask
    assign vr_st_en = {DW_B{~agu_idle_st}};

    // ----------------------------------------------------- MEMORY PORT LOGIC ----------------------------------------------------------------

    // memory could just run load/store in parallel with ALU if we implement queue
  
    // STORE
    // always @(posedge clk) begin
    //     mem_port_end_out <= agu_addr_end_st; 
    // end

    // TODO update with mask ld/st
    assign mem_port_valid_out   = rst_n & en_mem_out;
    assign mem_port_data_out    = {MEM_DATA_WIDTH{en_mem_out}} & vr_st_data_out;
    assign mem_port_addr_out    = ({MEM_DATA_WIDTH{en_mem_out}} & mem_addr_in_d) | ({MEM_DATA_WIDTH{mem_port_req_out}} & mem_addr_in_d);
    assign mem_port_be_out      = {(MEM_DW_B){1'b1}};// & vr_st_en;

    // LOAD
    assign vr_ld_data_in    = {DATA_WIDTH{rst_n & en_ld & mem_port_valid_in}} & mem_port_data_in; // FIXME this assumes no delay in receiving data!
    assign vr_ld_en         = {DW_B{en_ld}};

    // --------------------------------------------------- WRITEBACK STAGE LOGIC --------------------------------------------------------------
    assign vr_wr_data_in    = {DATA_WIDTH{rst_n & alu_valid_out & ~alu_mask_out}} & alu_data_out;

    assign vm_wr_data_in    = {DATA_WIDTH{rst_n & alu_valid_out & alu_mask_out}} & alu_data_out;

    // We may be able to reduce to 1 bit because we use AGNOSTIC ops only right?
    // Nah, combining mask and enable saves some logic overall
    assign vr_wr_en = {DW_B{~agu_idle_wr & ~alu_mask_out}} & alu_be_out;
    assign vm_wr_en = {DW_B{alu_valid_out & alu_mask_out}} & alu_be_out;     // write mask

    // -------------------------------------------------- SIGNAL PROPAGATION LOGIC ------------------------------------------------------------
    assign no_bubble = hold_reg_group & (reg_count > 0);

    always @(*) begin
        if (opcode_mnr === `MVV_TYPE && funct6 === 'h10) begin
            case (src_1)
                'h0,
                'h10,
                'h11:       sca_data_in_1 = {{(VEX_DATA_WIDTH-ADDR_WIDTH){1'b0}},src_1};
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
        if ((opcode_mnr_d[1]^opcode_mnr_d[0]) & (funct6_d === 'h10)) begin // vmv.s.x (mvx) vmv.x.s (mvv)
            case (sew)
                'h0: alu_req_be = {{(DW_B-1){1'b0}},{1'b1}};
                'h1: alu_req_be = {{(DW_B-2){1'b0}},{2'b11}};
                'h2: alu_req_be = {{(DW_B-4){1'b0}},{4'hF}};
                'h3: alu_req_be = {{(DW_B-8){1'b1}},{8'hFF}};
            endcase
            // alu_req_be = {{(VEX_DATA_WIDTH/8){1'b1}},{(DW_B - VEX_DATA_WIDTH/8){1'b0}}}; // FIXME :) We want to operate on vd[0] bytes only
        end else begin // FIXME -- how do we use AVL when it's a variable??
            // Next mask will always come from v0, we really only need to read and write masks for mask manipulation instructions
            alu_req_be = {DW_B{vm_d}} | vmask_ext; // vm=1 is unmasked -- just set be to 1 for unmasked insns to simplify ALU
        end
    end

    // wire    [DW_B-1:0] gen_avl_be;

    // generate_be #(.DATA_WIDTH(DATA_WIDTH), .DW_B(DW_B), .AVL_WIDTH(VEX_DATA_WIDTH)) gen_be_alu (.clk(clk), .rst_n (rst_n), .avl   (avl), .avl_be(gen_avl_be));

    reg wait_mem;

    always @(posedge clk) begin
        if(~rst_n) begin
            opcode_mjr_d    <= 'h0;
            opcode_mnr_d    <= 'h0;
            dest_d          <= 'h0;
            funct6_d        <= 'h0;
            vm_d            <= 'b1; // unmasked by default
            // src_1_d         <= 'h0;
            // src_2_d         <= 'h0;
            ld_valid        <= 'h0;
            avl_d           <= 'h0; // FIXME
            sca_data_in_1_d <= 'h0;
            sca_data_in_2_d <= 'h0;
            out_ack_d       <= 'b0;
            mem_addr_in_d   <= 'b0;

            out_ack_e       <= 'b0;
            out_ack_m       <= 'b0;

            vm_0            <= {(VLEN>>3){1'b1}};
        end else begin
            // all stalling should happen here
            opcode_mjr_d    <= ~stall ? opcode_mjr  : (no_bubble ? opcode_mjr_d : 'h0);
            opcode_mnr_d    <= ~stall ? opcode_mnr  : (no_bubble ? opcode_mnr_d : 'h0);
            dest_d          <= ~stall ? dest        : (no_bubble ? dest_d       : 'h0);
            funct6_d        <= ~stall ? funct6      : (no_bubble ? funct6_d     : 'h0);
            // src_1_d         <= ~stall ? src_1       : (no_bubble ? src_1_d      : 'h0);
            // src_2_d         <= ~stall ? src_2       : (no_bubble ? src_2_d      : 'h0);
            vm_d            <= ~stall ? vm          : (no_bubble ? vm_d         : 'b1);
            avl_d           <= ~stall ? avl         : avl_d;
            sca_data_in_1_d <= ~stall ? {{(DATA_WIDTH-VEX_DATA_WIDTH){sca_data_in_1[VEX_DATA_WIDTH-1]}}, sca_data_in_1} : (no_bubble ? sca_data_in_1_d : 'h0);
            sca_data_in_2_d <= ~stall ? {{(DATA_WIDTH-VEX_DATA_WIDTH){sca_data_in_2[VEX_DATA_WIDTH-1]}}, sca_data_in_2} : (no_bubble ? sca_data_in_2_d : 'h0);
            out_ack_d       <= ~stall && insn_valid_f;

            mem_port_req_out <= ~stall ? en_req_mem : (no_bubble & mem_port_req_out);
            mem_addr_in_d   <= ~stall ? ({VEX_DATA_WIDTH{en_vs3 | en_req_mem}} & data_in_1_f) :
                                        (no_bubble ? (mem_addr_in_d + (DATA_WIDTH/8)) : 'h0);

            out_ack_e       <= (alu_valid_out & alu_resp_end);
            out_ack_m       <= (mem_port_valid_in & mem_port_done_ld) | (mem_port_done_st);

            // FIXME timing is off -- hold these values until we get a response
            opcode_mjr_m    <= opcode_mjr_d;
            dest_m          <= wait_mem ? dest_m : dest_d;
            ld_valid        <= wait_mem;
            wait_mem        <= (opcode_mjr_m === `LD_INSN) | (wait_mem & ~mem_port_done_ld);

            vexrv_data_out  <= (opcode_mjr_d === `OP_INSN && opcode_mnr_d === `CFG_TYPE) ? avl : 'h0;
            vexrv_valid_out <= out_ack_e || out_ack_m || (opcode_mjr_d === `OP_INSN && opcode_mnr_d === `CFG_TYPE);

            // update
            if (alu_valid_out & alu_mask_out & alu_addr_out === 'h0) begin
                vm_0    <= (vm_0 & ~(alu_be_out << (DW_B*alu_off_out))) | ((alu_data_out[DW_B-1:0] & alu_be_out) << (DW_B*alu_off_out)); // FIXME this will need to be shifted for VLEN > DW_B
            end
        end
    end

endmodule

module generate_be #(
    parameter DATA_WIDTH        = 64,
    parameter DW_B              = DATA_WIDTH/8,
    parameter AVL_WIDTH         = DATA_WIDTH)
    (
    input                           clk,
    input                           rst_n,
    input       [  AVL_WIDTH-1:0]   avl,
    output  reg [       DW_B-1:0]   avl_be
    );

    genvar i;

    generate
        for (i = 0; i < DW_B; i=i+1) begin
            always @(posedge clk) begin
                // set high if 
                avl_be[i] <= rst_n & (i < avl);
            end
        end
    endgenerate
endmodule

module extract_mask #(
    parameter VLEN          = 128,
    parameter DATA_WIDTH    = 64,
    parameter DW_B          = DATA_WIDTH/8,
    parameter VLEN_B        = VLEN/8
    ) (
    input                   clk,
    input                   rst_n,
    input   [  VLEN_B-1:0]  vmask_in,
    input   [         2:0]  sew,
    input   [         7:0]  reg_count,
    output  [    DW_B-1:0]  vmask_out
    );
    reg [DW_B-1:0]  vmask_sew [0:3];

    genvar i, j;

    // Generate mask byte enable based on SEW and current index in vector
    generate
        for (j = 0; j < 3; j = j + 1) begin
            for (i = 0; i < (DW_B >> j); i = i + 1) begin
                always @(*) begin
                    vmask_sew[j][((i+1)<<j)-1:i<<j] = {(1<<j){vmask_in[reg_count*(DW_B >> j) + i]}};
                end
            end
        end
    endgenerate

    assign vmask_out = {DW_B{rst_n}} & vmask_sew[sew];

endmodule