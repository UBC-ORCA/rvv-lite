`include "vec_regfile.sv"
`include "insn_decoder.sv"
`include "addr_gen_unit.sv"
`include "cfg_unit.sv"
`include "vALU.v"

`define LD_INSN 7'h07
`define ST_INSN 7'h27
`define OP_INSN 7'h57
// `define VV_TYPE 3'h0
// `define VX_TYPE 3'h4
// `define VI_TYPE 3'h3
`define CF_TYPE 3'h7

module rvv_proc_main #(
    parameter VLEN = 64,        // vector length in bits
    parameter XLEN = 32,        // not sure, data width maybe?
    parameter NUM_VEC = 32,     // number of available vector registers
    parameter INSN_WIDTH = 32,  // width of a single instruction
    parameter DATA_WIDTH = 64,
    parameter DW_B = DATA_WIDTH/8,  // DATA_WIDTH in bytes
    parameter ADDR_WIDTH = 5,   //$clog2(NUM_VEC)
    parameter MEM_ADDR_WIDTH = 5,   // WE ONLY HAVE MEM ADDRESSES AS REGISTER IDS RIGHT NOW
    parameter REG_PORTS = 3
) (
    input clk,
    input rst,
    input [INSN_WIDTH-1:0] insn_in, // make this a queue I guess?
    input [DATA_WIDTH-1:0] mem_port_in,
    input mem_port_valid_in,
    output reg mem_port_ready_out,
    output reg [DATA_WIDTH-1:0] mem_port_out,
    output reg [MEM_ADDR_WIDTH-1:0] mem_port_addr_out,
    output reg mem_port_valid_out,
    output reg proc_rdy
);
    logic [DW_B-1:0] vr_en [REG_PORTS-1:0];
    logic vr_rw [REG_PORTS-1:0];
    logic vr_active [REG_PORTS-1:0];
    logic [ADDR_WIDTH-1:0] vr_addr [REG_PORTS-1:0];
    logic [VLEN-1:0] vr_data_in [REG_PORTS-1:0];
    logic [VLEN-1:0] vr_data_out [REG_PORTS-1:0];

    logic [DW_B-1:0] vr_ld_en;
    logic [DW_B-1:0] vr_st_en;
    logic vr_ld_active;
    logic vr_st_active;
    logic [ADDR_WIDTH-1:0] vr_ld_addr;
    logic [ADDR_WIDTH-1:0] vr_st_addr;
    logic [VLEN-1:0] vr_ld_data_in;
    logic [VLEN-1:0] vr_st_data_out;

    logic [INSN_WIDTH-1:0] insn_in_f;

    logic stall;

    // DEBUG
    logic [VLEN-1:0] vr_data_out_0;
    logic [VLEN-1:0] vr_data_out_1;
    logic [VLEN-1:0] vr_data_out_2;
    logic [VLEN-1:0] vr_data_in_0;
    logic [VLEN-1:0] vr_data_in_1;
    logic [VLEN-1:0] vr_data_in_2;
    logic [ADDR_WIDTH-1:0] vr_addr_0;
    logic [ADDR_WIDTH-1:0] vr_addr_1;
    logic [ADDR_WIDTH-1:0] vr_addr_2;

    // insn decomposition -- mostly general
    // realistically these shouldn't be registered but it makes it easier for now
    logic [6:0] opcode_mjr;
    logic [2:0] opcode_mnr;
    logic [4:0] dest;    // rd, vd, or vs3 -- TODO make better name lol
    logic [4:0] src_1;   // rs1, vs1, or imm/uimm
    logic [4:0] src_2;   // rs2, vs2, or imm -- for mem could be lumop, sumop

    // vmem
    logic [2:0] width;
    logic [1:0] mop;
    logic mew;
    logic [2:0] nf;

    // vcfg
    logic [10:0] vtype_11;
    logic [9:0]  vtype_10;
    logic [1:0]  cfg_type;
    logic       cfg_en;

    // valu
    logic vm;
    logic [5:0] funct6;

    // Use these to determine where hazards will fall
    logic req_vs1;
    logic req_vs2;
    logic req_vs3;
    logic req_vd;

    logic en_vs1;
    logic en_vs2;
    logic en_vs3;
    logic en_vd;

    // value propagation signals
    logic [6:0] opcode_mjr_d;
    logic [2:0] opcode_mnr_d;
    logic [4:0] src_1_d;
    logic [4:0] src_2_d;
    logic [4:0] dest_d;    // rd, vd, or vs3 -- TODO make better name lol
    logic [5:0] funct6_d;
    logic       vm_d;

    logic [6:0] opcode_mjr_e;
    logic [2:0] opcode_mnr_e;
    logic [4:0] src_1_e;
    logic [4:0] src_2_e;
    logic [4:0] dest_e;   // rd, vd, or vs3 -- TODO make better name lol
    logic [5:0] funct6_e;
    logic       vm_e;

    logic [6:0] opcode_mjr_m;
    logic [2:0] opcode_mnr_m;
    logic [4:0] src_1_m;
    logic [4:0] src_2_m;
    logic [4:0] dest_m;    // rd, vd, or vs3 -- TODO make better name lol
    logic [5:0] funct6_m;

    logic [6:0] opcode_mjr_w;
    logic [2:0] opcode_mnr_w;
    logic [4:0] src_1_w;
    logic [4:0] src_2_w;
    logic [4:0] dest_w;    // rd, vd, or vs3 -- TODO make better name lol
    logic [5:0] funct6_w;

    // CONFIG VALUES
    logic [4:0] avl; // Application Vector Length (vlen effective)

    // VTYPE values
    logic [2:0]         sew;
    logic [2:0]         vlmul;
    logic [XLEN-1:0]    vtype;
    logic               vma;
    logic               vta;
    logic               vill;

    logic [XLEN-1:0]    vtype_nxt;
    logic [3:0]         reg_count;

    logic agu_idle [REG_PORTS-1:0];
    logic agu_idle_ld;
    logic agu_idle_st;

    logic alu_enable;
    logic [2:0] alu_req_sew;
    logic [DATA_WIDTH-1:0] s_ext_imm;
    logic [DATA_WIDTH-1:0] s_ext_imm_d;
    logic [DATA_WIDTH-1:0] s_ext_imm_e;

    //   wire alu_req_valid;
    //   wire alu_req_be;
    //   wire alu_req_vl;
    //   wire alu_req_start;
    //   wire alu_req_end;

    logic [DATA_WIDTH-1:0] alu_data_in1;
    logic [DATA_WIDTH-1:0] alu_data_in2;
    logic [DATA_WIDTH-1:0] alu_data_out;

    logic [ADDR_WIDTH-1:0] alu_req_addr_out;
    logic alu_valid_out;

    logic [2:0] opcode_mnr_e_0;

    logic hold_reg_group;
    logic raw_hazard;

    logic vec_has_hazard [0:NUM_VEC-1]; // use this to indicate that vec needs bubble????

    logic no_bubble;

    logic [ADDR_WIDTH-1:0] ld_addr;
    logic [DATA_WIDTH-1:0] ld_data_in;
    logic ld_valid;

    genvar i;

    //   wire alu_resp_valid;
    //   wire alu_req_ready;
    //   wire alu_req_vl_out;
    //   wire alu_req_be_out;

    // // -------------------------------------------------- CONNECTED MODULES ---------------------------------------------------------------------------------

    insn_decoder #(.INSN_WIDTH(INSN_WIDTH)) id (.clk(clk), .rst(rst), .insn_in(insn_in_f), .opcode_mjr(opcode_mjr), .opcode_mnr(opcode_mnr), .dest(dest), .src_1(src_1), .src_2(src_2),
        .width(width), .mop(mop), .mew(mew), .nf(nf), .vtype_11(vtype_11), .vtype_10(vtype_10), .vm(vm), .funct6(funct6), .cfg_type(cfg_type));

    // TODO: figure out how to make this single cycle, so we can fully pipeline lol
    addr_gen_unit #(.ADDR_WIDTH(ADDR_WIDTH)) agu_src1 (.clk(clk), .rst(rst), .en(en_vs1), .vlmul(vlmul), .addr_in(src_1), .addr_out(vr_addr[0]), .idle(agu_idle[0]));
    addr_gen_unit #(.ADDR_WIDTH(ADDR_WIDTH)) agu_src2 (.clk(clk), .rst(rst), .en(en_vs2), .vlmul(vlmul), .addr_in(src_2), .addr_out(vr_addr[1]), .idle(agu_idle[1]));
    addr_gen_unit #(.ADDR_WIDTH(ADDR_WIDTH)) agu_dest (.clk(clk), .rst(rst), .en(en_vd), .vlmul(vlmul), .addr_in(alu_req_addr_out), .addr_out(vr_addr[2]), .idle(agu_idle[2]));

    addr_gen_unit #(.ADDR_WIDTH(ADDR_WIDTH)) agu_st (.clk(clk), .rst(rst), .en(en_vs3), .vlmul(vlmul), .addr_in(dest), .addr_out(vr_st_addr), .idle(agu_idle_st));
    addr_gen_unit #(.ADDR_WIDTH(ADDR_WIDTH)) agu_ld (.clk(clk), .rst(rst), .en(ld_valid), .vlmul(vlmul), .addr_in(dest_d), .addr_out(vr_ld_addr), .idle(agu_idle_ld));

    // TODO: add normal regfile? connect to external one? what do here
    vec_regfile #(.VLEN(VLEN), .DATA_WIDTH(DATA_WIDTH), .ADDR_WIDTH(ADDR_WIDTH), .PORTS(REG_PORTS)) vr (.clk(clk), .rst(rst), .en(vr_en), .ld_en(vr_ld_en), .st_en(vr_st_en), .rw(vr_rw),
        .addr(vr_addr), .st_addr(vr_st_addr), .ld_addr(vr_ld_addr), .data_in(vr_data_in), .ld_data_in(vr_ld_data_in), .data_out(vr_data_out), .st_data_out(vr_st_data_out));

    // ------------------------- BEGIN DEBUG --------------------------
    // Read vector sources
    // TODO: add mask read logic
    assign vr_data_out_0 = vr_data_out[0];
    assign vr_data_out_1 = vr_data_out[1];
    assign vr_data_out_2 = vr_data_out[2];

    assign vr_data_in_0 = vr_data_in[0];
    assign vr_data_in_1 = vr_data_in[1];
    assign vr_data_in_2 = vr_data_in[2];

    assign vr_en_0 = |vr_en[0];
    assign vr_en_1 = |vr_en[1];
    assign vr_en_2 = |vr_en[2];

    assign vr_act_0 = vr_active[0];
    assign vr_act_1 = vr_active[1];

    assign vr_addr_0 = vr_addr[0];
    assign vr_addr_1 = vr_addr[1];
    assign vr_addr_2 = vr_addr[2];

    assign vr_rw_0 = vr_rw[0];
    assign vr_rw_2 = vr_rw[2];

    assign haz_0 = vec_has_hazard[0];
    assign haz_1 = vec_has_hazard[1];
    assign haz_2 = vec_has_hazard[2];
    assign haz_3 = vec_has_hazard[3];
    assign haz_4 = vec_has_hazard[4];
    assign haz_5 = vec_has_hazard[5];
    assign haz_6 = vec_has_hazard[6];
    assign haz_7 = vec_has_hazard[7];

    // ------------------------- END DEBUG --------------------------

    assign haz_src1 = vec_has_hazard[src_1] && en_vs1;
    assign haz_src2 = vec_has_hazard[src_2] && en_vs2;
    assign haz_str  = vec_has_hazard[dest] && en_vs3;
    assign haz_ld   = vec_has_hazard[dest] && (opcode_mjr === `LD_INSN);
    // Load doesn't really ever have hazards, since it just writes to a reg and that should be in order! Right?
    // WRONG -- CONSIDER CASE WHERE insn in the ALU path has the same dest addr. We *should* preserve write order there.

    // need to stall for register groupings
    // TODO: stall for hazards within 1 cycle -- we are at 2
    // TODO: Add valid instruction logic, so we don't count instructions twice
    always @(posedge clk or negedge rst) begin
        if (~rst) begin
            insn_in_f <= 0;
        end else begin
            insn_in_f <= stall ? insn_in_f : insn_in;
        end
    end

    assign stall = ~rst | (hold_reg_group & reg_count > 0) | haz_src1 | haz_src2 | haz_str | haz_ld;

    generate
        for (i = 0; i < NUM_VEC; i++) begin
            always @(posedge clk or negedge rst) begin
                if (~rst) begin
                    vec_has_hazard[i] <= 0; // pipeline is reset, no hazards
                end else begin
                    // set high if incoming vector is going to overwrite the destination, or it has a hazard that isn't being cleared this cycle
                    // else, set low
                    vec_has_hazard[i] <= (((dest === i) && (opcode_mjr === `OP_INSN && opcode_mnr != `CF_TYPE)) || (vec_has_hazard[i] && ~(((alu_req_addr_out === i) && alu_valid_out) || (dest_m === i && ld_valid)))); // FIXME opcode check
                end
            end
        end
    endgenerate

    assign proc_rdy = ~stall;
    // -------------------------------------------------- CONTROL SIGNALS ---------------------------------------------------------------------------------

    // VLEN AND VSEW
    // TODO: store AVL value in register
    assign vtype_nxt = cfg_type[1] ? {12'h0, vtype_10} : {11'h0, vtype_11};
    assign cfg_en    = (opcode_mjr === `OP_INSN && opcode_mnr === `CF_TYPE);

    cfg_unit #(.XLEN(XLEN), .VLEN(VLEN)) cfg_unit (.clk(clk), .rst(rst), .en(cfg_en), .vtype_nxt(vtype_nxt), .cfg_type(cfg_type), .src_1(src_1),
        .avl(avl), .sew(sew), .vlmul(vlmul), .vma(vma), .vta(vta), .vill(vill));

    // ---------------------------------------- ALU --------------------------------------------------------------------------------

    // TODO: hold values steady while waiting for multiple register groupings...
    assign hold_reg_group = rst & ((reg_count > 0) || (reg_count == 0 && (opcode_mjr === `ST_INSN || opcode_mjr === `LD_INSN || (opcode_mjr === `OP_INSN && opcode_mnr != `CF_TYPE)) && vlmul > 0));
    // hold if we are starting a reg group or currently processing one

    // SIGN-EXTENDED IMMEDIATE FOR ALU
    always_comb begin
        case (sew)
            3'h0:     s_ext_imm = {{(DATA_WIDTH-8){1'b0}}, {3{src_1[4]}}, src_1};
            3'h1:     s_ext_imm = {{(DATA_WIDTH-16){1'b0}}, {11{src_1[4]}}, src_1};
            3'h2:     s_ext_imm = {{(DATA_WIDTH-32){1'b0}}, {27{src_1[4]}}, src_1};
            3'h3:     s_ext_imm = {{(DATA_WIDTH-64){1'b0}}, {59{src_1[4]}}, src_1};
            default:  s_ext_imm = 3'h0;
        endcase
    end

    always @(posedge clk) begin
        if (~rst) begin
            reg_count   <= 'h0;
            s_ext_imm_d <= 'h0;
            s_ext_imm_e <= 'h0;
        end else begin
            reg_count <= (reg_count > 0)    ? reg_count - 1 : (hold_reg_group ? ((1'b1 << vlmul) - 1) : 0);

            s_ext_imm_d <= (reg_count === 0 && opcode_mjr === `OP_INSN) ? s_ext_imm : s_ext_imm_d; // latch value for register groupings

            // new simm when its an intermediate input and we aren't mid-instruction
            s_ext_imm_e <= s_ext_imm_d;
        end
    end

    // ALU INPUTS
    always @(posedge clk) begin
        alu_req_sew <= sew;
    end

    // ASSIGNING FIRST SOURCE BASED ON OPCODE TYPE (VX vs VI vs VV)
    always_comb begin
        // enable ALU if ALU op AND ((VR enabled AND valu.vv) OR valu.vi OR valu.vx)
        alu_enable  = (((vr_active[0] || vr_active[1]) && (opcode_mnr_e == 3'b0)) || (opcode_mnr_e == 3'b011) || (opcode_mnr_e == 3'b100)) && (opcode_mjr_e === `OP_INSN);

        case (opcode_mnr_e)
            3'h0:   alu_data_in1 = vr_data_out[0];  // valu.vv
            3'h3: begin // valu.vi
                case (alu_req_sew)
                    2'b00:    alu_data_in1 = {DW_B{s_ext_imm_e[7:0]}};
                    2'b01:    alu_data_in1 = {(DW_B/2){s_ext_imm_e[15:0]}};
                    2'b10:    alu_data_in1 = {(DW_B/4){s_ext_imm_e[31:0]}};
                    2'b11:    alu_data_in1 = {(DW_B/8){s_ext_imm_e[63:0]}};
                    default:  alu_data_in1 = {s_ext_imm_e};
                endcase
            end
            default:  alu_data_in1 = 'hX;
        endcase
    end

    // source 2 is always source 2 for ALU
    assign alu_data_in2 = vr_data_out[0];

    // TODO: update to use active low reset lol
    vALU #(.REQ_DATA_WIDTH(DATA_WIDTH), .RESP_DATA_WIDTH(DATA_WIDTH), .REQ_ADDR_WIDTH(ADDR_WIDTH)) alu (.clk(clk), .rst(~rst), .req_mask(vm_e),
        .req_valid(alu_enable), .req_func_id(funct6_e), .req_sew(sew[1:0]), .req_data0(alu_data_in1), .req_data1(alu_data_in2), .req_addr(dest_e),
        .resp_valid(alu_valid_out), .resp_data(alu_data_out), .req_addr_out(alu_req_addr_out));
    //  MISSING PORT CONNECTIONS:
    //     input      [REQ_BYTE_EN_WIDTH-1:0] req_be      ,
    //     input      [     REQ_VL_WIDTH-1:0] req_vl      ,
    //     input                              req_start   ,
    //     input                              req_end     ,
    //     output                             req_ready   ,
    //     output reg [     REQ_VL_WIDTH-1:0] req_vl_out  ,
    //     output reg [REQ_BYTE_EN_WIDTH-1:0] req_be_out
    // );

    // used only for OPIVV, OPFVV, OPMVV
    assign en_vs1 = (opcode_mjr === `OP_INSN && opcode_mnr >= 3'h0 && opcode_mnr <= 3'h2);// && ~hold_reg_group;

    // used for all ALU and one each of load/store
    // TODO FOR LD/STR: Implement indexed address offsets (the only time vs2 actually used)
    assign en_vs2 = (opcode_mjr === `OP_INSN && opcode_mnr !== `CF_TYPE && funct6 !== 'h17) || (opcode_mjr === `LD_INSN && mop[0]) || (opcode_mjr === `ST_INSN && mop[0]);//  && ~hold_reg_group;

    // used for ALU
    assign en_vd = alu_valid_out;
    // used for LOAD
    assign en_ld = (opcode_mjr_m == `LD_INSN);

    // used only for STORE-FP. OR with vs1, because there is no situation where vs1 and vs3 exist for the same insn
    assign en_vs3     = (opcode_mjr === `ST_INSN);
    assign en_mem_out = (opcode_mjr_m === `ST_INSN);
    assign en_mem_in  = (opcode_mjr_m === `LD_INSN);

    assign vr_rw[0] = agu_idle[0];
    assign vr_en[0] = {DW_B{~agu_idle[0]}};

    assign vr_rw[1] = agu_idle[1];
    assign vr_en[1] = {DW_B{~agu_idle[1]}};   //rst & en_vs2;

    always_ff @(posedge clk or negedge rst) begin : proc_
        if(~rst) begin
            vr_active[0] <= 0;
            vr_active[1] <= 0;
        end else begin
            vr_active[0] <= |vr_en[0];
            vr_active[1] <= |vr_en[1];
        end
    end

    // TODO: memory lol
    // could just run load/store in parallel with ALU theoretically

    // ----------------------------------------------------- MEMORY PORT LOGIC ----------------------------------------------------------------

    // STORE
    always_ff @(posedge clk or negedge rst) begin
        if(~rst) begin
            mem_port_out        <= 'hX;
            mem_port_addr_out   <= 'hX;
            mem_port_valid_out  <= 1'b0;
        end else begin
            mem_port_valid_out <= en_mem_out;
            if (en_mem_out) begin
                mem_port_out <= vr_data_out[0];
                // NOTE: This just points to a scalar register which holds an address to write to!
                // FIXME
                mem_port_addr_out <= dest_m;
            end
        end
    end

    // LOAD
    always_ff @(posedge clk or negedge rst) begin
        vr_ld_data_in  <= (rst && en_mem_in && mem_port_valid_in) ? mem_port_in : 'hX;
    end

    assign vr_ld_en = {DW_B{~agu_idle_ld}};

    // tell memory we're ready for the data if the instruction in the mem stage is a load.
    assign mem_port_ready_out = rst & en_mem_in;

    // --------------------------------------------------- WRITEBACK STAGE LOGIC --------------------------------------------------------------
    // This one is registered because we have to wait for the agu to give us our initial address
    always_ff @(posedge clk or negedge rst) begin
        vr_data_in[2] <= {DATA_WIDTH{rst & alu_valid_out}} & alu_data_out;
    end

    assign vr_rw[2] = ~agu_idle[2];
    assign vr_en[2] = {DW_B{~agu_idle[2]}}; // TODO: add byte masking

    // -------------------------------------------------- SIGNAL PROPAGATION LOGIC ------------------------------------------------------------
    assign no_bubble = hold_reg_group & ~(haz_src1 | haz_src2 | haz_str);

    always_ff @(posedge clk or negedge rst) begin
        if(~rst) begin
            opcode_mjr_d    <= 0;
            opcode_mnr_d    <= 0;
            dest_d          <= 0;
            funct6_d        <= 0;
            vm_d            <= 0;
            src_1_d         <= 0;
            ld_valid        <= 0;

            opcode_mjr_e    <= 0;
            opcode_mnr_e    <= 0;
            dest_e          <= 0;
            funct6_e        <= 0;
            vm_e            <= 0;

            opcode_mjr_m    <= 0;
            opcode_mnr_m    <= 0;
            dest_m          <= 0;
            src_1_m         <= 0;
        end else begin
            // all stalling should happen here
            // FIXME circular stall logic
            opcode_mjr_d    <= ~stall ? opcode_mjr  : (no_bubble ? opcode_mjr_d : 'h0);
            opcode_mnr_d    <= ~stall ? opcode_mnr  : (no_bubble ? opcode_mnr_d : 'h0);
            dest_d          <= ~stall ? dest        : (no_bubble ? dest_d       : 'h0);
            funct6_d        <= ~stall ? funct6      : (no_bubble ? funct6_d     : 'h0);
            src_1_d         <= ~stall ? src_1       : (no_bubble ? src_1_d      : 'h0);
            vm_d            <= ~stall ? vm          : (no_bubble ? vm_d         : 'b0);

            opcode_mjr_e    <= opcode_mjr_d;
            opcode_mnr_e    <= opcode_mnr_d;
            dest_e          <= dest_d;
            funct6_e        <= funct6_d;
            vm_e            <= vm_d;

            opcode_mjr_m    <= opcode_mjr_d;
            opcode_mnr_m    <= opcode_mnr_d;
            dest_m          <= dest_d;
            src_1_m         <= src_1_d;
            ld_valid        <= (opcode_mjr_d === `LD_INSN);
        end
    end

endmodule