`include "vec_regfile.sv"
`include "mask_regfile.sv"
`include "insn_decoder.sv"
`include "addr_gen_unit.sv"
`include "cfg_unit.sv"
`include "vALU/vALU.v"

`define LD_INSN 7'h07
`define ST_INSN 7'h27
`define OP_INSN 7'h57
// `define IVV_TYPE 3'h0
// `define FVV_TYPE 3'h1
// `define MVV_TYPE 3'h2
// `define IVI_TYPE 3'h3
// `define IVX_TYPE 3'h4
// `define _TYPE 3'h3
`define CF_TYPE 3'h7
`define AVL_WIDTH 5

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
    input       [VEX_DATA_WIDTH-1:0]    vexrv_data_in_1,    // memory address from load/store command?
    input       [VEX_DATA_WIDTH-1:0]    vexrv_data_in_2,
    output                              mem_port_ready_out,
    output reg  [MEM_DATA_WIDTH-1:0]    mem_port_out,
    output reg  [MEM_ADDR_WIDTH-1:0]    mem_port_addr_out,
    output                              mem_port_req,       // signal dicating request vs write I guess?
    output reg                          mem_port_valid_out,
    output                              proc_rdy,
    output reg  [VEX_DATA_WIDTH-1:0]    vexrv_data_out   // in theory anything writing to a scalar register should already know the dest register right?
    // TODO: add register config outputs?
);
    wire  [      DW_B-1:0]  vr_rd_en_1;
    wire  [      DW_B-1:0]  vr_rd_en_2;
    wire  [      DW_B-1:0]  vr_wr_en;
    
    wire  [      DW_B-1:0]  vm_rd_en_1;
    wire  [      DW_B-1:0]  vm_rd_en_2;
    wire  [      DW_B-1:0]  vm_wr_en;

    reg                     vr_rd_active_1;
    reg                     vr_rd_active_2;

    reg                     vm_rd_active_1;
    reg                     vm_rd_active_2;

    wire  [ADDR_WIDTH-1:0]  vr_rd_addr_1;
    wire  [ADDR_WIDTH-1:0]  vr_rd_addr_2;
    wire  [ADDR_WIDTH-1:0]  vr_wr_addr;

    wire  [ADDR_WIDTH-1:0]  vm_rd_addr_1;
    wire  [ADDR_WIDTH-1:0]  vm_rd_addr_2;
    wire  [ADDR_WIDTH-1:0]  vm_wr_addr;

    reg   [      VLEN-1:0]  vr_wr_data_in;
    wire  [      VLEN-1:0]  vr_rd_data_out_1;
    wire  [      VLEN-1:0]  vr_rd_data_out_2;

    reg   [      VLEN-1:0]  vm_wr_data_in;
    wire  [      VLEN-1:0]  vm_rd_data_out_1;
    wire  [      VLEN-1:0]  vm_rd_data_out_2; 

    wire  [      DW_B-1:0]  vr_ld_en;
    wire  [      DW_B-1:0]  vr_st_en;
    wire  [ADDR_WIDTH-1:0]  vr_ld_addr;
    wire  [ADDR_WIDTH-1:0]  vr_st_addr;
    reg   [      VLEN-1:0]  vr_ld_data_in;
    wire  [      VLEN-1:0]  vr_st_data_out;

    wire  [      DW_B-1:0]  vm_ld_en;
    wire  [      DW_B-1:0]  vm_st_en;
    wire  [ADDR_WIDTH-1:0]  vm_ld_addr;
    wire  [ADDR_WIDTH-1:0]  vm_st_addr;
    reg   [      VLEN-1:0]  vm_ld_data_in;
    wire  [      VLEN-1:0]  vm_st_data_out;

    reg   [INSN_WIDTH-1:0]  insn_in_f;

    wire                    stall;

    // insn decomposition -- mostly general
    wire  [           6:0]  opcode_mjr;
    wire  [           2:0]  opcode_mnr;
    wire  [           4:0]  dest;    // rd, vd, or vs3 -- TODO make better name lol
    wire  [           4:0]  src_1;   // rs1, vs1, or imm/uimm
    wire  [           4:0]  src_2;   // rs2, vs2, or imm -- for mem could be lumop, sumop

    // vmem
    wire  [           2:0]  width;
    wire  [           1:0]  mop;
    wire                    mew;
    wire  [           2:0]  nf;

    wire                    mask_en;

    // vcfg
    wire  [          10:0]  vtype_11;
    wire  [           9:0]  vtype_10;
    wire  [           1:0]  cfg_type;
    wire                    cfg_en;

    // valu
    wire                    vm;
    wire  [           5:0]  funct6;

    // Use these to determine where hazards will fall
    wire                    req_vs1;
    wire                    req_vs2;
    wire                    req_vs3;
    wire                    req_vd;

    wire                    en_vs1;
    wire                    en_vs2;
    wire                    en_vs3;
    wire                    en_vd;

    // value propagation signals
    reg   [           6:0]  opcode_mjr_d;
    reg   [           2:0]  opcode_mnr_d;
    reg   [           4:0]  src_1_d;
    reg   [           4:0]  src_2_d;
    reg   [           4:0]  dest_d;    // rd, vd, or vs3 -- TODO make better name lol
    reg   [           5:0]  funct6_d;
    reg                     vm_d;
    reg   [`AVL_WIDTH-1:0]  avl_d;

    reg   [           6:0]  opcode_mjr_e;
    reg   [           2:0]  opcode_mnr_e;
    reg   [           4:0]  src_1_e;
    reg   [           4:0]  src_2_e;
    reg   [           4:0]  dest_e;   // rd, vd, or vs3 -- TODO make better name lol
    reg   [           5:0]  funct6_e;
    reg                     vm_e;

    reg   [           6:0]  opcode_mjr_m;
    reg   [           2:0]  opcode_mnr_m;
    reg   [           4:0]  src_1_m;
    reg   [           4:0]  src_2_m;
    reg   [           4:0]  dest_m;    // rd, vd, or vs3 -- TODO make better name lol
    reg   [           5:0]  funct6_m;

    reg   [           6:0]  opcode_mjr_w;
    reg   [           2:0]  opcode_mnr_w;
    reg   [           4:0]  src_1_w;
    reg   [           4:0]  src_2_w;
    reg   [           4:0]  dest_w;    // rd, vd, or vs3 -- TODO make better name lol
    reg   [           5:0]  funct6_w;

    // CONFIG VALUES -- config unit flops them, these are just connector wires
    wire  [`AVL_WIDTH-1:0]  avl; // Application Vector Length (vlen effective)

    // VTYPE values
    wire  [           2:0]  sew;
    wire  [           2:0]  vlmul;
    wire  [      XLEN-1:0]  vtype;
    wire                    vma;
    wire                    vta;
    wire                    vill;

    wire  [      XLEN-1:0]  vtype_nxt;
    reg   [           3:0]  reg_count;

    wire                    agu_idle_rd_1;
    wire                    agu_idle_rd_2;
    wire                    agu_idle_wr;
    wire                    agu_idle_ld;
    wire                    agu_idle_st;

    wire                    alu_enable;
    reg   [           2:0]  alu_req_sew;
    reg   [`AVL_WIDTH-1:0]  alu_req_avl;
    
    reg   [DATA_WIDTH-1:0]  s_ext_imm;
    reg   [DATA_WIDTH-1:0]  s_ext_imm_d;
    reg   [DATA_WIDTH-1:0]  s_ext_imm_e;

    //   wire alu_req_valid;
    //   wire alu_req_be;
    //   wire alu_req_start;
    //   wire alu_req_end;

    reg   [DATA_WIDTH-1:0]  alu_data_in1;
    reg   [DATA_WIDTH-1:0]  alu_data_in2;
    wire  [DATA_WIDTH-1:0]  alu_data_out;

    wire  [ADDR_WIDTH-1:0]  alu_req_addr_out;
    wire                    alu_valid_out;
    wire  [`AVL_WIDTH-1:0]  alu_avl_out;

    wire                    hold_reg_group;
    reg                     vec_has_hazard  [0:NUM_VEC-1]; // use this to indicate that vec needs bubble????
    wire                    no_bubble;

    reg   [ADDR_WIDTH-1:0]  ld_addr;
    reg   [DATA_WIDTH-1:0]  ld_data_in;
    reg                     ld_valid;

    // Detect hazards for operands
    wire                    haz_src1;
    wire                    haz_src2;
    wire                    haz_str;
    wire                    haz_ld;

    genvar i;

    //   wire alu_resp_valid;
    //   wire alu_req_ready;
    //   wire alu_req_vl_out;
    //   wire alu_req_be_out;

    // -------------------------------------------------- CONNECTED MODULES ---------------------------------------------------------------------------------

    insn_decoder #(.INSN_WIDTH(INSN_WIDTH)) id (.clk(clk), .rst_n(rst_n), .insn_in(insn_in_f), .opcode_mjr(opcode_mjr), .opcode_mnr(opcode_mnr), .dest(dest), .src_1(src_1), .src_2(src_2),
        .width(width), .mop(mop), .mew(mew), .nf(nf), .vtype_11(vtype_11), .vtype_10(vtype_10), .vm(vm), .funct6(funct6), .cfg_type(cfg_type));

    // TODO: figure out how to make this single cycle, so we can fully pipeline lol
    addr_gen_unit #(.ADDR_WIDTH(ADDR_WIDTH)) agu_src1 (.clk(clk), .rst_n(rst_n), .en(en_vs1), .vlmul(vlmul), .addr_in(src_1), .addr_out(vr_rd_addr_1), .idle(agu_idle_rd_1));
    addr_gen_unit #(.ADDR_WIDTH(ADDR_WIDTH)) agu_src2 (.clk(clk), .rst_n(rst_n), .en(en_vs2), .vlmul(vlmul), .addr_in(src_2), .addr_out(vr_rd_addr_2), .idle(agu_idle_rd_2));
    addr_gen_unit #(.ADDR_WIDTH(ADDR_WIDTH)) agu_dest (.clk(clk), .rst_n(rst_n), .en(en_vd), .vlmul(vlmul), .addr_in(alu_req_addr_out), .addr_out(vr_wr_addr), .idle(agu_idle_wr));

    addr_gen_unit #(.ADDR_WIDTH(ADDR_WIDTH)) agu_st (.clk(clk), .rst_n(rst_n), .en(en_vs3), .vlmul(vlmul), .addr_in(dest), .addr_out(vr_st_addr), .idle(agu_idle_st));
    addr_gen_unit #(.ADDR_WIDTH(ADDR_WIDTH)) agu_ld (.clk(clk), .rst_n(rst_n), .en(ld_valid), .vlmul(vlmul), .addr_in(dest_d), .addr_out(vr_ld_addr), .idle(agu_idle_ld));

    // TODO: add normal regfile? connect to external one? what do here
    vec_regfile #(.VLEN(VLEN), .DATA_WIDTH(DATA_WIDTH), .ADDR_WIDTH(ADDR_WIDTH)) vr (.clk(clk),.rst_n(rst_n),
                .rd_en_1(vr_rd_en_1),.rd_en_2(vr_rd_en_2),.wr_en(vr_wr_en),.ld_en(vr_ld_en),.st_en(vr_st_en),
                .rd_addr_1(vr_rd_addr_1),.rd_addr_2(vr_rd_addr_2),.wr_addr(vr_wr_addr),.ld_addr(vr_ld_addr),.st_addr(vr_st_addr),
                .wr_data_in(vr_wr_data_in),.ld_data_in(vr_ld_data_in),.st_data_out(vr_st_data_out),.rd_data_out_1(vr_rd_data_out_1),.rd_data_out_2(vr_rd_data_out_2));

    mask_regfile #(.VLEN(VLEN), .DATA_WIDTH(DATA_WIDTH), .ADDR_WIDTH(ADDR_WIDTH)) vmr (.clk(clk),.rst_n(rst_n),
                .rd_en_1(vm_rd_en_1),.rd_en_2(vm_rd_en_2),.wr_en(vm_wr_en),.ld_en(vm_ld_en),.st_en(vm_st_en),
                .rd_addr_1(vm_rd_addr_1),.rd_addr_2(vm_rd_addr_2),.wr_addr(vm_wr_addr),.ld_addr(vm_ld_addr),.st_addr(vr_st_addr),
                .wr_data_in(vm_wr_data_in),.ld_data_in(vm_ld_data_in),.st_data_out(vm_st_data_out),.rd_data_out_1(vm_rd_data_out_1),.rd_data_out_2(vm_rd_data_out_2));
  
    cfg_unit #(.XLEN(XLEN), .VLEN(VLEN)) cfg_unit (.clk(clk), .rst_n(rst_n), .en(cfg_en), .vtype_nxt(vtype_nxt), .cfg_type(cfg_type), .src_1(src_1),
        .avl(avl), .sew(sew), .vlmul(vlmul), .vma(vma), .vta(vta), .vill(vill));

    // ------------------------- BEGIN DEBUG --------------------------
    // Read vector sources
    // TODO: add mask read logic

    // assign haz_0            = vec_has_hazard[0];
    // assign haz_1            = vec_has_hazard[1];
    // assign haz_2            = vec_has_hazard[2];
    // assign haz_3            = vec_has_hazard[3];
    // assign haz_4            = vec_has_hazard[4];
    // assign haz_5            = vec_has_hazard[5];
    // assign haz_6            = vec_has_hazard[6];
    // assign haz_7            = vec_has_hazard[7];

    // ------------------------- END DEBUG --------------------------

    // -------------------------------------------------- FETCH AND HAZARD DETECTION -----------------------------------------------------------------------
    // need to stall for register groupings
    // TODO: stall for hazards within 1 cycle -- we are at 2

    always @(posedge clk) begin
        insn_in_f   <= {INSN_WIDTH{rst_n}} & (stall ? insn_in_f : (insn_valid ? insn_in : 'h0));
    end

    generate
        for (i = 0; i < NUM_VEC; i=i+1) begin
            always @(posedge clk) begin
                // set high if incoming vector is going to overwrite the destination, or it has a hazard that isn't being cleared this cycle
                // else, set low
                vec_has_hazard[i] <= rst_n & (((dest === i) && (opcode_mjr === `OP_INSN && opcode_mnr != `CF_TYPE)) || (vec_has_hazard[i] && ~(((alu_req_addr_out === i) && alu_valid_out) || (dest_m === i && ld_valid)))); // FIXME opcode check
            end
        end
    endgenerate
  
    assign haz_src1         = vec_has_hazard[src_1] && en_vs1;
    assign haz_src2         = vec_has_hazard[src_2] && en_vs2;
    assign haz_str          = vec_has_hazard[dest]  && en_vs3;
    assign haz_ld           = vec_has_hazard[dest]  && (opcode_mjr === `LD_INSN);
    // Load doesn't really ever have hazards, since it just writes to a reg and that should be in order! Right?
    // WRONG -- CONSIDER CASE WHERE insn in the ALU path has the same dest addr. We *should* preserve write order there.

    assign stall    = ~rst_n | (hold_reg_group & reg_count > 0) | haz_src1 | haz_src2 | haz_str | haz_ld;


    assign proc_rdy = ~stall;
    // -------------------------------------------------- CONTROL SIGNALS ---------------------------------------------------------------------------------

    // VLEN AND VSEW
    // TODO: store AVL value in register
    assign vtype_nxt = cfg_type[1] ? {12'h0, vtype_10} : {11'h0, vtype_11};
    assign cfg_en    = (opcode_mjr === `OP_INSN && opcode_mnr === `CF_TYPE);

    // ---------------------------------------- ALU --------------------------------------------------------------------------------

    // TODO: hold values steady while waiting for multiple register groupings...
    assign hold_reg_group   = rst_n & ((reg_count > 0) || (reg_count == 0 && (opcode_mjr === `ST_INSN || opcode_mjr === `LD_INSN || (opcode_mjr === `OP_INSN && opcode_mnr != `CF_TYPE)) && vlmul > 0));
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
        alu_req_sew <= sew;
    end

    assign alu_enable   = (((vr_rd_active_1 || vr_rd_active_2) && (opcode_mnr_e == 3'b0)) || (opcode_mnr_e == 3'b011) || (opcode_mnr_e == 3'b100)) && (opcode_mjr_e === `OP_INSN);

    // ASSIGNING FIRST SOURCE BASED ON OPCODE TYPE (VX vs VI vs VV)
    always @(*) begin
        // enable ALU if ALU op AND ((VR enabled AND valu.vv) OR valu.vi OR valu.vx)
        // alu_enable  = (((vr_rd_active_1 || vr_rd_active_2) && (opcode_mnr_e == 3'b0)) || (opcode_mnr_e == 3'b011) || (opcode_mnr_e == 3'b100)) && (opcode_mjr_e === `OP_INSN);

        case (opcode_mnr_e)
            3'h0:   alu_data_in1    = vr_rd_data_out_1;  // valu.vv
            3'h3: begin // valu.vi
                case (alu_req_sew)
                    2'b00:    alu_data_in1  = {DW_B{s_ext_imm_e[7:0]}};
                    2'b01:    alu_data_in1  = {(DW_B/2){s_ext_imm_e[15:0]}};
                    2'b10:    alu_data_in1  = {(DW_B/4){s_ext_imm_e[31:0]}};
                    2'b11:    alu_data_in1  = {(DW_B/8){s_ext_imm_e[63:0]}};
                    default:  alu_data_in1  = {s_ext_imm_e};
                endcase
            end
            default:  alu_data_in1  = 'hX;
        endcase

        alu_data_in2 = vr_rd_data_out_1; // source 2 is always source 2 for ALU
    end

    // TODO: update to use active low reset lol
    vALU #(.REQ_DATA_WIDTH(DATA_WIDTH), .RESP_DATA_WIDTH(DATA_WIDTH), .REQ_ADDR_WIDTH(ADDR_WIDTH), .REQ_VL_WIDTH(4))
            alu (.clk(clk), .rst(~rst_n), .req_mask(vm_e),
        .req_valid(alu_enable), .req_op_mnr(opcode_mnr_e), .req_func_id(funct6_e), .req_sew(sew[1:0]), .req_data0(alu_data_in1), .req_data1(alu_data_in2), .req_addr(dest_e),
        .resp_valid(alu_valid_out), .resp_data(alu_data_out), .req_addr_out(alu_req_addr_out), .req_vl(avl), .req_vl_out(alu_avl_out));
    //  MISSING PORT CONNECTIONS:
    //     input      [REQ_BYTE_EN_WIDTH-1:0] req_be      ,
    //     input                              req_start   ,
    //     input                              req_end     ,
    //     output                             req_ready   ,
    //     output reg [REQ_BYTE_EN_WIDTH-1:0] req_be_out
    // );

    // used only for OPIVV, OPFVV, OPMVV
    assign en_vs1   = (opcode_mjr === `OP_INSN && opcode_mnr <= 3'h2);// && ~hold_reg_group;

    // used for all ALU and one each of load/store
    // TODO FOR LD/STR: Implement indexed address offsets (the only time vs2 actually used)
    assign en_vs2   = (opcode_mjr === `OP_INSN && opcode_mnr !== `CF_TYPE && funct6 !== 'h17) || (opcode_mjr === `LD_INSN && mop[0]) || (opcode_mjr === `ST_INSN && mop[0]);//  && ~hold_reg_group;

    // used for ALU
    assign en_vd    = alu_valid_out;
    // used for LOAD
    assign en_ld    = (opcode_mjr_m == `LD_INSN);

    // used only for STORE-FP. OR with vs1, because there is no situation where vs1 and vs3 exist for the same insn
    assign en_vs3       = (opcode_mjr === `ST_INSN);
    assign en_mem_out   = (opcode_mjr_m === `ST_INSN);
    assign en_mem_in    = (opcode_mjr_m === `LD_INSN);

    // TODO: and with mask
    assign vr_rd_en_1 = {DW_B{~agu_idle_rd_1}};
    assign vr_rd_en_2 = {DW_B{~agu_idle_rd_2}};   //rst_n & en_vs2;

    always @(posedge clk) begin
        vr_rd_active_1 <= rst_n & |vr_rd_en_1;
        vr_rd_active_2 <= rst_n & |vr_rd_en_2;
    end

    // TODO: and with mask
    assign vr_st_en = {DW_B{~agu_idle_st}};

    // always @(posedge clk) begin
    //     vr_st_active <= rst_n & |vr_st_en;
    // end

    // assign mem_port_valid_out = vr_st_active;
    // ----------------------------------------------------- MEMORY PORT LOGIC ----------------------------------------------------------------

    // memory could just run load/store in parallel with ALU if we implement queue
  
    // STORE
    always @(posedge clk) begin
        mem_port_valid_out  <= rst_n & en_mem_out;
        if (en_mem_out) begin
            mem_port_out    <= vr_st_data_out;
            // NOTE: This just points to a scalar register which holds an address to write to!
            // FIXME
            mem_port_addr_out   <= dest_m;
        end
    end

    // LOAD
    always @(posedge clk) begin
        if (en_mem_in && mem_port_valid_in) begin
            vr_ld_data_in   <= {DATA_WIDTH{rst_n}} & mem_port_in;
        end
    end

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

    assign vr_wr_en = {DW_B{~agu_idle_wr}}; // TODO: add byte masking

    // -------------------------------------------------- SIGNAL PROPAGATION LOGIC ------------------------------------------------------------
    assign no_bubble = hold_reg_group & ~(haz_src1 | haz_src2 | haz_str);

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

            opcode_mjr_e    <= 'h0;
            opcode_mnr_e    <= 'h0;
            dest_e          <= 'h0;
            funct6_e        <= 'h0;
            vm_e            <= 'b1;
            alu_req_avl     <= 'h0; // FIXME

            opcode_mjr_m    <= 'h0;
            opcode_mnr_m    <= 'h0;
            dest_m          <= 'h0;
            src_1_m         <= 'h0;
        end else begin
            // all stalling should happen here
            // FIXME circular stall logic
            opcode_mjr_d    <= ~stall ? opcode_mjr  : (no_bubble ? opcode_mjr_d : 'h0);
            opcode_mnr_d    <= ~stall ? opcode_mnr  : (no_bubble ? opcode_mnr_d : 'h0);
            dest_d          <= ~stall ? dest        : (no_bubble ? dest_d       : 'h0);
            funct6_d        <= ~stall ? funct6      : (no_bubble ? funct6_d     : 'h0);
            src_1_d         <= ~stall ? src_1       : (no_bubble ? src_1_d      : 'h0);
            vm_d            <= ~stall ? vm          : (no_bubble ? vm_d         : 'b1);
            avl_d           <= ~stall ? avl         : avl_d;

            opcode_mjr_e    <= opcode_mjr_d;
            opcode_mnr_e    <= opcode_mnr_d;
            dest_e          <= dest_d;
            funct6_e        <= funct6_d;
            vm_e            <= vm_d;
            alu_req_avl     <= avl_d;

            opcode_mjr_m    <= opcode_mjr_d;
            opcode_mnr_m    <= opcode_mnr_d;
            dest_m          <= dest_d;
            src_1_m         <= src_1_d;
            ld_valid        <= (opcode_mjr_d === `LD_INSN);
        end
    end

endmodule