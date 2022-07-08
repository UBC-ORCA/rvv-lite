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

// TODO: change signals back to reg/wire in proc because vivado hates them :)

module rvv_proc_main #(
    parameter VLEN              = 64,           // vector length in bits
    parameter XLEN              = 32,           // not sure, data width maybe?
    parameter NUM_VEC           = 32,           // number of available vector registers
    parameter INSN_WIDTH        = 32,           // width of a single instruction
    parameter DATA_WIDTH        = 64,
    parameter DW_B              = DATA_WIDTH/8, // DATA_WIDTH in bytes
    parameter ADDR_WIDTH        = 5,            //$clog2(NUM_VEC)
    parameter MEM_ADDR_WIDTH    = 32,           // We need to get this from VexRiscV
    parameter MEM_DATA_WIDTH    = 64,
    parameter VEX_DATA_WIDTH    = 32
) (
    input                               clk,
    input                               rst_n,
    input       [    INSN_WIDTH-1:0]    insn_in, // make this a queue I guess?
    input                               insn_valid,
    input       [    DATA_WIDTH-1:0]    mem_port_in,
    input                               mem_port_valid_in,
    input       [VEX_DATA_WIDTH-1:0]    vexrv_data_in_1,    // memory address from load/store command
    input       [VEX_DATA_WIDTH-1:0]    vexrv_data_in_2,
    output                              mem_port_ready_out,
    output reg  [MEM_DATA_WIDTH-1:0]    mem_port_out,
    output reg  [MEM_ADDR_WIDTH-1:0]    mem_port_addr_out,
    output                              mem_port_req,       // signal dicating request vs write I guess?
    output reg                          mem_port_valid_out,
    output                              proc_rdy,
    output reg  [VEX_DATA_WIDTH-1:0]    vexrv_data_out,   // in theory anything writing to a scalar register should already know the dest register right?
    output reg                          vexrv_valid_out
    // TODO: add register config outputs?
);
    wire  [          DW_B-1:0]  vr_rd_en_1;
    wire  [          DW_B-1:0]  vr_rd_en_2;
    wire  [          DW_B-1:0]  vr_wr_en;
    
    // reg   [        VLEN/8-1:0]  vmask; // theFIXME maybe store in the regfile
    // reg   [          DW_B-1:0]  vmask_curr [0:3];
    reg   [          DW_B-1:0]  vmask_ext_e, vmask_ext_m;
    reg   [          DW_B-1:0]  vm_src_1, vm_src_2; // do we need these? no
    reg   [        VLEN/8-1:0]  vm_0; // The currently set mask based on the mask ops before?
    wire  [          DW_B-1:0]  vm_rd_en_1;
    wire  [          DW_B-1:0]  vm_rd_en_2;
    wire  [          DW_B-1:0]  vm_wr_en;

    reg                         vr_rd_active_1;
    reg                         vr_rd_active_2;

    reg                         vm_rd_active_1;
    reg                         vm_rd_active_2;

    wire  [    ADDR_WIDTH-1:0]  vr_rd_addr_1;
    wire  [    ADDR_WIDTH-1:0]  vr_rd_addr_2;
    wire  [    ADDR_WIDTH-1:0]  vr_wr_addr;

    wire  [    ADDR_WIDTH-1:0]  vm_rd_addr_1;
    wire  [    ADDR_WIDTH-1:0]  vm_rd_addr_2;
    wire  [    ADDR_WIDTH-1:0]  vm_wr_addr;

    reg   [          VLEN-1:0]  vr_wr_data_in;
    wire  [          VLEN-1:0]  vr_rd_data_out_1;
    wire  [          VLEN-1:0]  vr_rd_data_out_2;

    reg   [          VLEN-1:0]  vm_wr_data_in;
    wire  [          VLEN-1:0]  vm_rd_data_out_1;
    wire  [          VLEN-1:0]  vm_rd_data_out_2; 

    wire  [          DW_B-1:0]  vr_ld_en;
    wire  [          DW_B-1:0]  vr_st_en;
    wire  [    ADDR_WIDTH-1:0]  vr_ld_addr;
    wire  [    ADDR_WIDTH-1:0]  vr_st_addr;
    reg   [          VLEN-1:0]  vr_ld_data_in;
    wire  [          VLEN-1:0]  vr_st_data_out;

    wire  [          DW_B-1:0]  vm_ld_en;
    wire  [          DW_B-1:0]  vm_st_en;
    wire  [    ADDR_WIDTH-1:0]  vm_ld_addr;
    wire  [    ADDR_WIDTH-1:0]  vm_st_addr;
    reg   [          VLEN-1:0]  vm_ld_data_in;
    wire  [          VLEN-1:0]  vm_st_data_out;

    reg   [    INSN_WIDTH-1:0]  insn_in_f;
    reg                         insn_valid_f;
    // wire                    mem_in_busy;
    reg                         mem_in_done;
    reg   [ VEX_DATA_WIDTH-1:0] data_in_1_f;
    reg   [ VEX_DATA_WIDTH-1:0] data_in_2_f;

    wire                        stall;

    wire                        en_mem_in;
    wire                        en_mem_out;
    reg   [MEM_ADDR_WIDTH-1:0]  mem_addr_in;
    reg   [MEM_ADDR_WIDTH-1:0]  mem_addr_in_d;
    reg   [MEM_ADDR_WIDTH-1:0]  mem_addr_out;

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
    reg                         en_vs1_d;
    wire                        en_vs2;
    reg                         en_vs2_d;
    wire                        en_vs3;
    reg                         en_vs3_d;
    wire                        en_vd;

    // value propagation signals
    reg   [               6:0]  opcode_mjr_d;
    reg   [               2:0]  opcode_mnr_d;
    reg   [               4:0]  src_1_d;
    reg   [               4:0]  src_2_d;
    reg   [               4:0]  dest_d;    // rd, vd, or vs3 -- TODO make better name lol
    reg   [               5:0]  funct6_d;
    reg                         vm_d;
    reg   [VEX_DATA_WIDTH-1:0]  avl_d;
    reg   [VEX_DATA_WIDTH-1:0]  sca_data_in_1_d;
    reg   [VEX_DATA_WIDTH-1:0]  sca_data_in_2_d;


    reg   [               6:0]  opcode_mjr_e;
    reg   [               2:0]  opcode_mnr_e;
    reg   [               4:0]  src_1_e;
    reg   [               4:0]  src_2_e;
    reg   [               4:0]  dest_e;   // rd, vd, or vs3 -- TODO make better name lol
    reg   [               5:0]  funct6_e;
    reg                         vm_e;
    reg   [VEX_DATA_WIDTH-1:0]  sca_data_in_1_e;
    reg   [VEX_DATA_WIDTH-1:0]  sca_data_in_2_e;

    reg   [               6:0]  opcode_mjr_m;
    reg   [               2:0]  opcode_mnr_m;
    reg   [               4:0]  src_1_m;
    reg   [               4:0]  src_2_m;
    reg   [               4:0]  dest_m;    // rd, vd, or vs3 -- TODO make better name lol
    reg   [               5:0]  funct6_m;
    reg   [               4:0]  prev_ld_reg;

    reg   [               6:0]  opcode_mjr_w;
    reg   [               2:0]  opcode_mnr_w;
    reg   [               4:0]  src_1_w;
    reg   [               4:0]  src_2_w;
    reg   [               4:0]  dest_w;    // rd, vd, or vs3 -- TODO make better name lol
    reg   [               5:0]  funct6_w;

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
    reg   [               2:0]  reg_count;

    wire                        agu_idle_rd_1;
    wire                        agu_idle_rd_2;
    wire                        agu_idle_wr;
    wire                        agu_idle_ld;
    wire                        agu_idle_st;

    wire                        alu_enable;
    reg   [               2:0]  alu_req_sew;
    reg   [VEX_DATA_WIDTH-1:0]  alu_req_avl;
    
    reg   [    DATA_WIDTH-1:0]  s_ext_imm;
    reg   [    DATA_WIDTH-1:0]  s_ext_imm_d;
    reg   [    DATA_WIDTH-1:0]  s_ext_imm_e;

    reg   [    DATA_WIDTH-1:0]  alu_data_in1;
    reg   [    DATA_WIDTH-1:0]  alu_data_in2;
    wire  [    DATA_WIDTH-1:0]  alu_data_out;

    wire  [    ADDR_WIDTH-1:0]  alu_req_addr_out;
    wire                        alu_valid_out;
    wire  [VEX_DATA_WIDTH-1:0]  alu_avl_out;
    wire                        alu_mask_out;
    reg   [          DW_B-1:0]  alu_req_be;
    reg   [               3:0]  alu_vr_idx;

    wire                        hold_reg_group;
    reg                         vec_haz  [0:NUM_VEC-1]; // use this to indicate that vec needs bubble????
    wire                        vec_haz_set     [0:NUM_VEC-1]; // use this to indicate that vec needs bubble????
    wire                        vec_haz_clr     [0:NUM_VEC-1]; // use this to indicate that vec needs bubble????
    wire                        no_bubble;

    reg   [    ADDR_WIDTH-1:0]  ld_addr;
    reg   [    DATA_WIDTH-1:0]  ld_data_in;
    reg                         ld_valid;

    // Detect hazards for operands
    wire                        haz_src1;
    wire                        haz_src2;
    wire                        haz_str;
    wire                        haz_ld;

    wire                        haz_new_src1;
    wire                        haz_new_src2;
    wire                        haz_new_str;
    wire                        haz_new_ld;

    genvar i,j;

    //   wire alu_req_start;
    //   wire alu_req_end;
    //   wire alu_req_ready;
    //   wire alu_req_vl_out;
    //   wire alu_req_be_out;

    // -------------------------------------------------- CONNECTED MODULES ---------------------------------------------------------------------------------

    insn_decoder #(.INSN_WIDTH(INSN_WIDTH)) id (.clk(clk), .rst_n(rst_n), .insn_in(insn_in_f), .opcode_mjr(opcode_mjr), .opcode_mnr(opcode_mnr), .dest(dest), .src_1(src_1), .src_2(src_2),
        .width(width), .mop(mop), .mew(mew), .nf(nf), .vtype_11(vtype_11), .vtype_10(vtype_10), .vm(vm), .funct6(funct6), .cfg_type(cfg_type));
  
//   insn_decoder #(.INSN_WIDTH(INSN_WIDTH)) pre_d (.clk(clk), .rst_n(rst_n), .insn_in(insn_in), .opcode_mjr(opcode_mjr_f), .opcode_mnr(opcode_mnr_f), .dest(dest_f), .src_1(src_1_f), .src_2(src_2_f),
//         .width(width), .mop(mop), .mew(mew), .nf(nf), .vtype_11(vtype_11), .vtype_10(vtype_10), .vm(vm), .funct6(funct6), .cfg_type(cfg_type));

    // TODO: figure out how to make this single cycle, so we can fully pipeline lol
    addr_gen_unit #(.ADDR_WIDTH(ADDR_WIDTH)) agu_src1 (.clk(clk), .rst_n(rst_n), .en(en_vs1_d), .vlmul(vlmul), .addr_in(src_1), .addr_out(vr_rd_addr_1), .idle(agu_idle_rd_1));
    addr_gen_unit #(.ADDR_WIDTH(ADDR_WIDTH)) agu_src2 (.clk(clk), .rst_n(rst_n), .en(en_vs2_d), .vlmul(vlmul), .addr_in(src_2), .addr_out(vr_rd_addr_2), .idle(agu_idle_rd_2));
    addr_gen_unit #(.ADDR_WIDTH(ADDR_WIDTH)) agu_dest (.clk(clk), .rst_n(rst_n), .en(en_vd), .vlmul(vlmul), .addr_in(alu_req_addr_out), .addr_out(vr_wr_addr), .idle(agu_idle_wr));

    addr_gen_unit #(.ADDR_WIDTH(ADDR_WIDTH)) agu_st (.clk(clk), .rst_n(rst_n), .en(en_vs3_d), .vlmul(vlmul), .addr_in(dest), .addr_out(vr_st_addr), .idle(agu_idle_st));
    addr_gen_unit #(.ADDR_WIDTH(ADDR_WIDTH)) agu_ld (.clk(clk), .rst_n(rst_n), .en(ld_valid), .vlmul(vlmul), .addr_in(dest_m), .addr_out(vr_ld_addr), .idle(agu_idle_ld));

    // TODO: add normal regfile? connect to external one? what do here
    vec_regfile #(.VLEN(VLEN), .DATA_WIDTH(DATA_WIDTH), .ADDR_WIDTH(ADDR_WIDTH)) vr (.clk(clk),.rst_n(rst_n),
                .rd_en_1(vr_rd_en_1),.rd_en_2(vr_rd_en_2),.wr_en(vr_wr_en),.ld_en(vr_ld_en),.st_en(vr_st_en),
                .rd_addr_1(vr_rd_addr_1),.rd_addr_2(vr_rd_addr_2),.wr_addr(vr_wr_addr),.ld_addr(vr_ld_addr),.st_addr(vr_st_addr),
                .wr_data_in(vr_wr_data_in),.ld_data_in(vr_ld_data_in),.st_data_out(vr_st_data_out),.rd_data_out_1(vr_rd_data_out_1),.rd_data_out_2(vr_rd_data_out_2));

    mask_regfile #(.VLEN(VLEN), .DATA_WIDTH(DATA_WIDTH), .ADDR_WIDTH(ADDR_WIDTH)) vmr (.clk(clk),.rst_n(rst_n),
                .rd_en_1(vm_rd_en_1),.rd_en_2(vm_rd_en_2),.wr_en(vm_wr_en),.ld_en(vm_ld_en),.st_en(vm_st_en),
                .rd_addr_1(vm_rd_addr_1),.rd_addr_2(vm_rd_addr_2),.wr_addr(vm_wr_addr),.ld_addr(vm_ld_addr),.st_addr(vm_st_addr),
                .wr_data_in(vm_wr_data_in),.ld_data_in(vm_ld_data_in),.st_data_out(vm_st_data_out),.rd_data_out_1(vm_rd_data_out_1),.rd_data_out_2(vm_rd_data_out_2));
  
    cfg_unit #(.XLEN(XLEN), .VLEN(VLEN)) cfg_unit (.clk(clk), .rst_n(rst_n), .en(cfg_en), .vtype_nxt(vtype_nxt), .cfg_type(cfg_type), .src_1(src_1), .avl_set(avl_set),
        .avl_new(data_in_1_f), .avl(avl), .sew(sew), .vlmul(vlmul), .vma(vma), .vta(vta), .vill(vill), .new_vl(new_vl));

    extract_mask #(.VLEN(VLEN), .DATA_WIDTH(DATA_WIDTH)) vm_s1 (.clk(clk), .rst_n(rst_n), .vmask_in(vm_rd_data_out_1), .sew(sew), .reg_count(reg_count), .vmask_out(vm_src_1));
    extract_mask #(.VLEN(VLEN), .DATA_WIDTH(DATA_WIDTH)) vm_s2 (.clk(clk), .rst_n(rst_n), .vmask_in(vm_rd_data_out_2), .sew(sew), .reg_count(reg_count), .vmask_out(vm_src_2));
    // FIXME lol unsure which mask we're supposed to use tbh. v0? idk.
    extract_mask #(.VLEN(VLEN), .DATA_WIDTH(DATA_WIDTH)) vm_alu (.clk(clk), .rst_n(rst_n), .vmask_in(vm_0), .sew(sew), .reg_count(reg_count), .vmask_out(vmask_ext_e));

    // ------------------------- BEGIN DEBUG --------------------------
    // Read vector sources
    // TODO: add mask read logic

    assign haz_24_new        = vec_haz_set[24];
    assign haz_24_clr        = vec_haz_clr[24];
    assign haz_24            = vec_haz[24];
    assign haz_25_new        = vec_haz_set[25];
    assign haz_25_clr        = vec_haz_clr[25];
    assign haz_25            = vec_haz[25];
    assign haz_26_new        = vec_haz_set[26];
    assign haz_26_clr        = vec_haz_clr[26];
    assign haz_26            = vec_haz[26];
    assign haz_27_new        = vec_haz_set[27];
    assign haz_27_clr        = vec_haz_clr[27];
    assign haz_27            = vec_haz[27];

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
    generate
        for (i = 0; i < NUM_VEC; i=i+1) begin
            // we shouldn't set the hazard unless we are actually processing a new instruction I think
            assign vec_haz_set[i] = (~stall & dest === i) && ((opcode_mjr === `OP_INSN && opcode_mnr != `CFG_TYPE) || opcode_mjr === `LD_INSN);
            assign vec_haz_clr[i] = ((vr_wr_addr === i) && |vr_wr_en) || (vr_ld_addr === i && |vr_ld_en);
            //(dest_m === i && opcode_mjr_m === `LD_INSN)))); // FIXME opcode check
            always @(posedge clk) begin
                // set high if incoming vector is going to overwrite the destination, or it has a hazard that isn't being cleared this cycle
                // else, set low
                vec_haz[i] <= rst_n & (vec_haz_set[i] | vec_haz[i]) & ~vec_haz_clr[i];
            end
        end
    endgenerate
  
    // FIXME this logic wouldn't work for v1 = v1 + v1
    assign haz_new_src1     = vec_haz_set[src_1] & ~vec_haz_clr[src_1] & en_vs1;
    assign haz_src1         = vec_haz[src_1] & ~vec_haz_clr[src_1] & en_vs1;
    assign haz_new_src2     = vec_haz_set[src_2] & ~vec_haz_clr[src_2] & en_vs2;
    assign haz_src2         = vec_haz[src_2] & ~vec_haz_clr[src_2] & en_vs2;
    assign haz_str          = vec_haz[dest] & ~vec_haz_clr[dest] & en_vs3;
    assign haz_new_str      = vec_haz_set[dest] & ~vec_haz_clr[dest] & en_vs3;
    assign haz_ld           = ((vec_haz_set[dest] || vec_haz[dest]) && ~vec_haz_clr[dest]) && (opcode_mjr === `LD_INSN);
    // Load doesn't really ever have hazards, since it just writes to a reg and that should be in order! Right?
    // WRONG -- CONSIDER CASE WHERE insn in the ALU path has the same dest addr. We *should* preserve write order there.

    assign stall    = ~rst_n | (hold_reg_group & reg_count > 0) | haz_src1 | haz_src2 | haz_str;// | haz_ld;

    assign proc_rdy = ~stall;
    // -------------------------------------------------- CONTROL SIGNALS ---------------------------------------------------------------------------------

    // VLEN AND VSEW
    // TODO: store AVL value in register
    assign vtype_nxt = cfg_type[1] ? {12'h0, vtype_10} : {11'h0, vtype_11};
    assign cfg_en    = (opcode_mjr === `OP_INSN && opcode_mnr === `CFG_TYPE);
    assign avl_set   = {(dest === 'h0),(src_1 === 'h0)}; // determines if rd and rs1 are non-zero, as AVL setting depends on this

    // ---------------------------------------- ALU --------------------------------------------------------------------------------

    // TODO: hold values steady while waiting for multiple register groupings...
    assign hold_reg_group   = rst_n & ((reg_count > 0) || (reg_count == 0 && (opcode_mjr === `ST_INSN || opcode_mjr === `LD_INSN || (opcode_mjr === `OP_INSN && opcode_mnr != `CFG_TYPE)) && vlmul > 0));
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

    // // FIXME
    // initial begin
    //     vmask = {VLEN>>3{1'b1}};
    // end

    // // Generate mask byte enable based on SEW and current index in vector
    // generate
    //     for (j = 0; j < 3; j = j + 1) begin
    //         for (i = 0; i < (DW_B >> j); i = i + 1) begin
    //             always @(*) begin
    //                 vmask_curr[j][((i+1)<<j)-1:i<<j] = {(1<<j){vmask[reg_count*(DW_B >> j) + i]}};
    //             end
    //         end
    //     end
    // endgenerate

    always @(posedge clk) begin
        if (~rst_n) begin
            reg_count   <= 'h0;
            s_ext_imm_d <= 'h0;
            s_ext_imm_e <= 'h0;
        end else begin
            reg_count   <= (reg_count > 0)    ? reg_count - 1 : (hold_reg_group ? ((1'b1 << vlmul) - 1) : 0);

            s_ext_imm_d <= (reg_count === 0 && opcode_mjr === `OP_INSN) ? s_ext_imm : s_ext_imm_d; // latch value for register groupings

            // new simm when its an intermediate input and we aren't mid-instruction
            s_ext_imm_e <= s_ext_imm_d;
        end
    end


    // ALU INPUTS
    always @(posedge clk) begin
        alu_req_sew     <= sew;
        alu_vr_idx      <= ((1'b1 << vlmul) - 1) - reg_count;
    end

    assign alu_enable   = (opcode_mjr_e === `OP_INSN) && (  ((vr_rd_active_1 || vr_rd_active_2) && (opcode_mnr_e == `IVV_TYPE || opcode_mnr_e == `MVV_TYPE)) ||
                                                            (opcode_mnr_e == `IVI_TYPE) || (opcode_mnr_e == `IVX_TYPE) || (opcode_mnr_e == `MVX_TYPE)   ||
                                                            (opcode_mnr_e == `MVV_TYPE && funct6_e == 'h14));

    // assign alu_vr_idx   = {3{alu_enable}} & ((1'b1 << vlmul) - 1) - reg_count;

    // ASSIGNING FIRST SOURCE BASED ON OPCODE TYPE (VX vs VI vs VV)
    // TODO: test scalar versions!
    always @(*) begin
        // enable ALU if ALU op AND ((VR enabled AND valu.vv) OR valu.vi OR valu.vx)
        case (opcode_mnr_e)
            3'h0,
            3'h1,
            3'h2:
                case (funct6_e[5:3])
                    3'b010: begin
                        case (funct6_e[2:0])
                            // vid.v
                            3'b100:     alu_data_in1    = {{(DATA_WIDTH-5){1'b0}},s_ext_imm_e[4:0]}; // use s_ext_imm because it already exists
                            default:    alu_data_in1    = vr_rd_data_out_1;  // valu.vv
                        endcase
                    end
                    3'b011:     alu_data_in1 = vm_rd_data_out_1;
                    default:    alu_data_in1 = vr_rd_data_out_1;  // valu.vv
                endcase
            3'h3: begin // valu.vi
                case (alu_req_sew)
                    2'b00:    alu_data_in1  = {DW_B{s_ext_imm_e[7:0]}};
                    2'b01:    alu_data_in1  = {(DW_B/2){s_ext_imm_e[15:0]}};
                    2'b10:    alu_data_in1  = {(DW_B/4){s_ext_imm_e[31:0]}};
                    2'b11:    alu_data_in1  = {(DW_B/8){s_ext_imm_e[63:0]}};
                    default:  alu_data_in1  = {s_ext_imm_e};
                endcase
            end
            3'h4,
            3'h5,
            3'h6: begin // valu.vx
                case (alu_req_sew)
                    2'b00:    alu_data_in1  = {DW_B{sca_data_in_1_e[7:0]}};
                    2'b01:    alu_data_in1  = {(DW_B/2){sca_data_in_1_e[15:0]}};
                    2'b10:    alu_data_in1  = {(DW_B/4){sca_data_in_1_e[31:0]}};
                    2'b11:    alu_data_in1  = {(DW_B/8){{32{sca_data_in_1_e[31]}},{sca_data_in_1_e[31:0]}}};
                    default:  alu_data_in1  = {sca_data_in_1_e};
                endcase
            end
            default:  alu_data_in1  = 'hX;
        endcase

        case (funct6_e[5:3])
            3'b011:     alu_data_in2 = vm_rd_data_out_2;    // mask function
            default:    alu_data_in2 = vr_rd_data_out_2; // source 2 is always source 2 for ALU
        endcase
    end

    // TODO: update to use active low reset lol
    vALU #(.REQ_DATA_WIDTH(DATA_WIDTH), .RESP_DATA_WIDTH(DATA_WIDTH), .REQ_ADDR_WIDTH(ADDR_WIDTH), .REQ_VL_WIDTH(4))
            alu (.clk(clk), .rst(~rst_n), .req_mask(vm_e), .req_be(alu_req_be), .req_vr_idx(alu_vr_idx),
        .req_valid(alu_enable), .req_op_mnr(opcode_mnr_e), .req_func_id(funct6_e), .req_sew(sew[1:0]), .req_data0(alu_data_in1), .req_data1(alu_data_in2), .req_addr(dest_e),
        .resp_valid(alu_valid_out), .resp_data(alu_data_out), .req_addr_out(alu_req_addr_out), .req_vl(alu_req_avl), .req_vl_out(alu_avl_out), .req_mask_out(alu_mask_out));
    //  MISSING PORT CONNECTIONS:
    //     input                              req_start   ,
    //     input                              req_end     ,
    //     output                             req_ready   ,
    //     output reg [REQ_BYTE_EN_WIDTH-1:0] req_be_out
    // );

    // used only for OPIVV, OPFVV, MVV_TYPE (excl VID)
    assign en_vs1   = (opcode_mjr === `OP_INSN && opcode_mnr <= 3'h2 && funct6 != 'h14 && funct6);// && ~hold_reg_group;

    // used for all ALU (not move or id) and one each of load/store
    // TODO FOR LD/STR: Implement indexed address offsets (the only time vs2 actually used)
    assign en_vs2   = (opcode_mjr === `OP_INSN && opcode_mnr !== `CFG_TYPE && funct6 !== 'h17 && funct6 != 'h14) || (opcode_mjr === `LD_INSN && mop[0]) || (opcode_mjr === `ST_INSN && mop[0]);//  && ~hold_reg_group;

    // used for ALU
    assign en_vd    = alu_valid_out & ~alu_mask_out;    // write data
    assign vm_wr_en = alu_valid_out & alu_mask_out;     // write mask
    // used for LOAD
    assign en_ld    = (opcode_mjr_m === `LD_INSN);

    // used only for STORE-FP. OR with vs1, because there is no situation where vs1 and vs3 exist for the same insn
    assign en_vs3       = (opcode_mjr === `ST_INSN);
    assign en_mem_out   = (opcode_mjr_m === `ST_INSN);
    assign en_mem_in    = (opcode_mjr_m === `LD_INSN);

    // TODO: and with mask -- actually maybe dont idk it'll save cycles
    // FIXME can increase mask op throughput by skipping agu, but this simplifies for now
    assign vr_rd_en_1 = {DW_B{~agu_idle_rd_1 & funct6_d[5:3] != 3'b011}}; // don't actually read data if it's a mask op!
    assign vm_rd_en_1 = {DW_B{~agu_idle_rd_1 & funct6_d[5:3] == 3'b011}}; // only enable if it's a mask op!

    assign vr_rd_en_2 = {DW_B{~agu_idle_rd_2 & funct6_d[5:3] != 3'b011}}; // don't actually read data if it's a mask op!
    assign vm_rd_en_2 = {DW_B{~agu_idle_rd_2 & funct6_d[5:3] == 3'b011}}; // only enable if it's a mask op!

    // FIXME this is not to spec -- vm should return only the bits corresponding to the elements we want (vm doesn't do grouping!)
    // TODO merge vm and vr and just add another port for the mask probably (simplifies logic!)
    assign vm_rd_addr_1 = src_1_d;
    assign vm_rd_addr_2 = src_2_d;
    assign vm_wr_addr   = alu_req_addr_out;

    always @(posedge clk) begin
        vr_rd_active_1 <= rst_n & |vr_rd_en_1;
        vr_rd_active_2 <= rst_n & |vr_rd_en_2;
    end

    // TODO: and with mask
    assign vr_st_en = {DW_B{~agu_idle_st}};

    // ----------------------------------------------------- MEMORY PORT LOGIC ----------------------------------------------------------------

    // memory could just run load/store in parallel with ALU if we implement queue
  
    // STORE
    always @(posedge clk) begin
        mem_port_valid_out      <= rst_n & en_mem_out;
        if (en_mem_out) begin
            mem_port_out        <= vr_st_data_out;
            // VFU passes in the address so we don't have to think about it :)
            // FIXME - confirm timing isn't messed up (hazard detection should protect it though)
            mem_port_addr_out   <= mem_addr_out;
        end
    end

    // LOAD
    always @(posedge clk) begin
        if (en_mem_in && mem_port_valid_in) begin
            vr_ld_data_in   <= {DATA_WIDTH{rst_n}} & mem_port_in;
        end
      
        mem_in_done <= (en_mem_in && mem_port_valid_in);
    end
  
    // assign mem_in_busy  = 

    assign vr_ld_en     = {DW_B{~agu_idle_ld}};

    // tell memory we're ready for the data if the instruction in the mem stage is a load.
    assign mem_port_ready_out = rst_n & en_mem_in;

    // --------------------------------------------------- WRITEBACK STAGE LOGIC --------------------------------------------------------------
    // This one is registered because we have to wait for the agu to give us our initial address
    always @(posedge clk) begin
        if (alu_valid_out) begin
            vr_wr_data_in   <= {DATA_WIDTH{rst_n}} & alu_data_out;
        end
    end

    // WE may be able to reduce to 1 bit because we use AGNOSTIC ops only
    assign vr_wr_en = {DW_B{~agu_idle_wr}}; // TODO: add byte masking

    // -------------------------------------------------- SIGNAL PROPAGATION LOGIC ------------------------------------------------------------
    assign no_bubble = hold_reg_group & (reg_count > 0);


    // FIXME timing is off lol
    always @(*) begin
        if (opcode_mnr == `MVV_TYPE && funct6 == 'h10) begin
          case (src_1)
                'h0,
                'h10,
                'h11:       sca_data_in_1 = {{(VEX_DATA_WIDTH-ADDR_WIDTH){1'b0}},src_1};
                default:    sca_data_in_1 = data_in_1_f;
            endcase // vs1
        end else begin
            sca_data_in_1 = data_in_1_f;
        end
    end
    always @(*) begin
        if (opcode_mnr == `MVX_TYPE && funct6 == 'h10) begin
          case (src_2)
                'h0:        sca_data_in_2 = {{(VEX_DATA_WIDTH-ADDR_WIDTH){1'b0}},src_2};
                default:    sca_data_in_2 = data_in_2_f;
            endcase // vs2
        end else begin
            sca_data_in_2 = data_in_2_f;
        end
    end

    always @(*) begin
        if (opcode_mjr === `ST_INSN) begin
            mem_addr_in = data_in_1_f;
        end
    end

    // Adding byte enable for ALU
    always @(*) begin
        if (opcode_mnr_e == `MVX_TYPE && funct6_e == 'h10) begin
            alu_req_be = {{(VEX_DATA_WIDTH/8){1'b1}},{(DW_B - VEX_DATA_WIDTH/8){1'b0}}}; // FIXME :) We want to operate on vd[0] bytes only
        end else begin // FIXME -- how do we use AVL when it's a variable??
            // FIXME how the f do we decide which mask to use?
            alu_req_be = {DW_B{vm}} | vm_src_1; // vm=1 is unmasked -- just set be to 1 for unmasked insns to simplify ALU
        end
    end

    wire    [DW_B-1:0] gen_avl_be;

    generate_be #(.DATA_WIDTH(DATA_WIDTH), .DW_B(DW_B), .AVL_WIDTH(VEX_DATA_WIDTH)) gen_be_alu (.clk(clk), .rst_n (rst_n), .avl   (avl), .avl_be(gen_avl_be));

    always @(posedge clk) begin
        if(~rst_n) begin
            opcode_mjr_d    <= 'h0;
            opcode_mnr_d    <= 'h0;
            dest_d          <= 'h0;
            funct6_d        <= 'h0;
            vm_d            <= 'b1; // unmasked by default?
            src_1_d         <= 'h0;
            ld_valid        <= 'h0;
            avl_d           <= 'h0; // FIXME
            sca_data_in_1_d <= 'h0;
            sca_data_in_2_d <= 'h0;
            out_ack_d       <= 'b0;
            mem_addr_in_d   <= 'b0;

            opcode_mjr_e    <= 'h0;
            opcode_mnr_e    <= 'h0;
            dest_e          <= 'h0;
            funct6_e        <= 'h0;
            vm_e            <= 'b1;
            alu_req_avl     <= 'h0; // FIXME
            sca_data_in_1_e <= 'h0;
            sca_data_in_2_e <= 'h0;
            out_ack_e       <= 'b0;
            vmask_ext_e     <= 'b1;

            opcode_mjr_m    <= 'h0;
            opcode_mnr_m    <= 'h0;
            dest_m          <= 'h0;
            src_1_m         <= 'h0;
            out_ack_m       <= 'b0;
            vmask_ext_m     <= 'b1;

            mem_addr_out    <= 'b0;
        end else begin
            // all stalling should happen here
            // FIXME circular stall logic
            opcode_mjr_d    <= ~stall ? opcode_mjr  : (no_bubble ? opcode_mjr_d : 'h0);
            opcode_mnr_d    <= ~stall ? opcode_mnr  : (no_bubble ? opcode_mnr_d : 'h0);
            dest_d          <= ~stall ? dest        : (no_bubble ? dest_d       : 'h0);
            funct6_d        <= ~stall ? funct6      : (no_bubble ? funct6_d     : 'h0);
            src_1_d         <= ~stall ? src_1       : (no_bubble ? src_1_d      : 'h0);
            vm_d            <= ~stall ? vm          : (no_bubble ? vm_d         : 'b1);
            en_vs1_d        <= en_vs1;
            en_vs2_d        <= en_vs2;
            en_vs3_d        <= en_vs3;
            avl_d           <= ~stall ? avl         : avl_d;
            sca_data_in_1_d <= ~stall ? {{(DATA_WIDTH-VEX_DATA_WIDTH){sca_data_in_1[VEX_DATA_WIDTH-1]}}, sca_data_in_1} : (no_bubble ? sca_data_in_1_d : 'h0);
            sca_data_in_2_d <= ~stall ? {{(DATA_WIDTH-VEX_DATA_WIDTH){sca_data_in_2[VEX_DATA_WIDTH-1]}}, sca_data_in_2} : (no_bubble ? sca_data_in_2_d : 'h0);
            out_ack_d       <= ~stall && insn_valid_f;
            mem_addr_in_d   <= ~stall ? mem_addr_in : (no_bubble ? mem_addr_in_d : 'h0);

            opcode_mjr_e    <= opcode_mjr_d;
            opcode_mnr_e    <= opcode_mnr_d;
            dest_e          <= dest_d;
            funct6_e        <= funct6_d;
            vm_e            <= vm_d;
            out_ack_e       <= out_ack_d;
            // vmask_ext_e     <= ~stall ? vmask_curr[sew]   : (no_bubble ? vmask_curr[sew] : 'b0); // assign straight to _e because reg_count is clocked in _d

            alu_req_avl     <= avl_d;
            sca_data_in_1_e <= sca_data_in_1_d;
            sca_data_in_2_e <= sca_data_in_2_d;
            opcode_mjr_m    <= opcode_mjr_d;
            opcode_mnr_m    <= opcode_mnr_d;
            dest_m          <= dest_d;
            src_1_m         <= src_1_d;
            ld_valid        <= (opcode_mjr_d === `LD_INSN);
            mem_addr_out    <= mem_addr_in_d; // TODO create memory controller to shift address update logic out

            vexrv_data_out  <= (opcode_mjr_d === `OP_INSN && opcode_mnr_d === `CFG_TYPE) ? avl : 'h0;
            vexrv_valid_out <= out_ack_e || out_ack_m;

            vm_0            <= {DW_B{alu_mask_out}} & alu_data_out; // FIXME this will need to be multi-cycle for VLEN > DW
        end
    end

endmodule

module generate_be #(
    parameter DATA_WIDTH        = 64,
    parameter DW_B              = DATA_WIDTH/8,
    parameter AVL_WIDTH         = DATA_WIDTH)
    (
    input                       clk,
    input                       rst_n,
    input   [  AVL_WIDTH-1:0]   avl,
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
    parameter DW_B          = DATA_WIDTH/8)
    (
    input                   clk,
    input                   rst_n,
    input       [DW_B-1:0]  vmask_in,
    input       [     2:0]  sew,
    input       [     2:0]  reg_count,
    output reg  [DW_B-1:0]  vmask_out
    );
    reg [DW_B-1:0]  vmask_sew [0:3];

    genvar i, j;
    
    // FIXME
    initial begin
        vmask_out = {VLEN>>3{1'b1}};
    end

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

    always @(posedge clk) begin
        vmask_out <= {DW_B{~rst_n}} & vmask_sew[sew];
    end

endmodule