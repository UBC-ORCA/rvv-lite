`include "vec_regfile.sv"
`include "insn_decoder.sv"
`include "addr_gen_unit.sv"
`include "vALU.v"

`define ALU_STG 5

// TODO: register groupings
// TODO:

module rvv_proc_main #(
    parameter VLEN = 64,        // vector length in bits
    parameter XLEN = 32,        // not sure, data width maybe?
    parameter NUM_VEC = 32,     // number of available vector registers
    parameter INSN_WIDTH = 32,  // width of a single instruction
    parameter DATA_WIDTH = 64,
    parameter DW_B = DATA_WIDTH/8,  // DATA_WIDTH in bytes
    parameter ADDR_WIDTH = 5,   //$clog2(NUM_VEC)
    parameter REG_PORTS = 3
) (
    input clk,
    input rst,
    input [INSN_WIDTH-1:0] insn_in, // make this a queue I guess?
    output proc_idle
);
    reg [DW_B-1:0] vr_en [REG_PORTS-1:0];
    reg vr_rw [REG_PORTS-1:0];
    reg [ADDR_WIDTH-1:0] vr_addr [REG_PORTS-1:0];
    reg [VLEN-1:0] vr_data_in [REG_PORTS-1:0];
    reg [VLEN-1:0] vr_data_out [REG_PORTS-1:0];
    reg [VLEN-1:0] vr_data_tmp [REG_PORTS-1:0];

    wire [VLEN-1:0] vr_data_out_0;
    wire [VLEN-1:0] vr_data_out_1;
    wire [VLEN-1:0] vr_data_out_2;
    wire [VLEN-1:0] vr_data_in_0;
    wire [VLEN-1:0] vr_data_in_1;
    wire [VLEN-1:0] vr_data_in_2;
    wire [ADDR_WIDTH-1:0] vr_addr_0;
    wire [ADDR_WIDTH-1:0] vr_addr_1;
    wire [ADDR_WIDTH-1:0] vr_addr_2;

    // insn decomposition -- mostly general
    // realistically these shouldn't be registered but it makes it easier for now
    wire [6:0] opcode_mjr;
    wire [2:0] opcode_mnr;
    wire [4:0] dest;    // rd, vd, or vs3 -- TODO make better name lol
    wire [4:0] src_1;   // rs1, vs1, or imm/uimm
    wire [4:0] src_2;   // rs2, vs2, or imm -- for mem could be lumop, sumop

    // vmem
    wire [2:0] width;
    wire [1:0] mop;
    wire mew;
    wire [2:0] nf;

    // vcfg
    wire [10:0] vtype_11;
    wire [9:0]  vtype_10;
    wire [1:0]  cfg_type;

    // valu
    wire vm;
    wire [5:0] funct6;

    // value propagation signals
    reg [6:0] opcode_mjr_d;
    reg [2:0] opcode_mnr_d;
    reg [4:0] dest_d;    // rd, vd, or vs3 -- TODO make better name lol
    reg [5:0] funct6_d;

    reg [6:0] opcode_mjr_e  [`ALU_STG-1:0];
    reg [2:0] opcode_mnr_e  [`ALU_STG-1:0];
    reg [4:0] dest_e        [`ALU_STG-1:0];    // rd, vd, or vs3 -- TODO make better name lol
    reg [5:0] funct6_e      [`ALU_STG-1:0];

    reg [6:0] opcode_mjr_m;
    reg [2:0] opcode_mnr_m;
    reg [4:0] dest_m;    // rd, vd, or vs3 -- TODO make better name lol
    reg [5:0] funct6_m;

    reg [6:0] opcode_mjr_w;
    reg [2:0] opcode_mnr_w;
    reg [4:0] dest_w;    // rd, vd, or vs3 -- TODO make better name lol
    reg [5:0] funct6_w;

    // CONFIG VALUES
    reg [4:0] avl; // Application Vector Length (vlen effective)
  
    // VTYPE values
    reg [2:0]       sew;
    reg [2:0]       vlmul;
    reg [XLEN-1:0]  vtype;
    reg             vma;
    reg             vta;
    reg             vill;
  
    wire [XLEN-1:0]  vtype_nxt;
    reg [3:0]       reg_count;

    wire agu_idle [REG_PORTS-1:0];

    reg alu_enable;
    reg [2:0] alu_req_sew;
    reg [DATA_WIDTH-1:0] s_ext_imm_d;
    reg [DATA_WIDTH-1:0] s_ext_imm_e;
//   wire alu_req_valid;
//   wire alu_req_be;
//   wire alu_req_vl;
//   wire alu_req_start;
//   wire alu_req_end;

    reg [DATA_WIDTH-1:0] alu_data_in1;
    reg [DATA_WIDTH-1:0] alu_data_in2;
    reg [DATA_WIDTH-1:0] alu_data_out;

    wire [ADDR_WIDTH-1:0] alu_req_addr_out;
    wire alu_valid_out;

//   wire alu_resp_valid;
//   wire alu_req_ready;
//   wire alu_req_vl_out;
//   wire alu_req_be_out;

// -------------------------------------------------- CONNECTED MODULES ---------------------------------------------------------------------------------

    insn_decoder #(.INSN_WIDTH(INSN_WIDTH)) id (.clk(clk), .rst(rst), .insn_in(insn_in), .opcode_mjr(opcode_mjr), .opcode_mnr(opcode_mnr), .dest(dest), .src_1(src_1), .src_2(src_2),
        .width(width), .mop(mop), .mew(mew), .nf(nf), .vtype_11(vtype_11), .vtype_10(vtype_10), .vm(vm), .funct6(funct6), .cfg_type(cfg_type));

    // TODO: figure out how to make this single cycle, so we can fully pipeline lol
    addr_gen_unit #(.ADDR_WIDTH(ADDR_WIDTH)) agu_src1 (.clk(clk), .rst(rst), .en(en_vs1), .vlmul(vlmul), .addr_in(src_1), .addr_out(vr_addr[0]), .idle(agu_idle[0]));
    addr_gen_unit #(.ADDR_WIDTH(ADDR_WIDTH)) agu_src2 (.clk(clk), .rst(rst), .en(en_vs2), .vlmul(vlmul), .addr_in(src_2), .addr_out(vr_addr[1]), .idle(agu_idle[1]));
    addr_gen_unit #(.ADDR_WIDTH(ADDR_WIDTH)) agu_dest (.clk(clk), .rst(rst), .en(en_vd), .vlmul(vlmul), .addr_in(alu_req_addr_out), .addr_out(vr_addr[2]), .idle(agu_idle[2]));

    // TODO: add normal regfile? connect to external one? what do here
    vec_regfile #(.VLEN(VLEN), .DATA_WIDTH(DATA_WIDTH), .ADDR_WIDTH(ADDR_WIDTH), .PORTS(REG_PORTS)) vr (.clk(clk), .rst(rst), .en(vr_en), .rw(vr_rw), .addr(vr_addr), .data_in(vr_data_in), .data_out(vr_data_out));

    // ------------------------- BEGIN DEBUG --------------------------
    // Read vector sources
    // TODO: add mask read logic
    assign vr_data_out_0 = vr_data_out[0];
    assign vr_data_out_1 = vr_data_out[1];
    assign vr_data_out_2 = vr_data_out[2];

    assign vr_data_in_0 = vr_data_in[0];
    assign vr_data_in_1 = vr_data_in[1];
    assign vr_data_in_2 = vr_data_in[2];

    assign vr_en_0 = vr_en[0];
    assign vr_en_1 = vr_en[1];
    assign vr_en_2 = vr_en[2];

    assign vr_addr_0 = vr_addr[0];
    assign vr_addr_1 = vr_addr[1];
    assign vr_addr_2 = vr_addr[2];

    assign vr_rw_0 = vr_rw[0];
    assign vr_rw_2 = vr_rw[2];

    // ------------------------- END DEBUG --------------------------

    // -------------------------------------------------- CONTROL SIGNALS ---------------------------------------------------------------------------------

    // VLEN AND VSEW
    // TODO: breakout into cfg unit
    // TODO: store AVL value in register
    assign vtype_nxt = cfg_type[1] ? {12'h0, vtype_10} : {11'h0, vtype_10};
      
    always @(posedge clk or negedge rst) begin
        if (~rst) begin
            sew     <= 3'h0;
            vlmul   <= 3'h0;
            vma     <= 1'b0;
            vta     <= 1'b0;
            vill    <= 1'b0;
            avl     <= VLEN;
        end else begin
            // only change if there is an explicit cfg instruction, obviously
            if (opcode_mjr === 7'h57 && opcode_mnr === 3'h7) begin
              // update vtype values if using vset{i}vli
                if (cfg_type[1] === 1'b0 || cfg_type === 2'b11) begin
                    vlmul   <= vtype_nxt[2:0];
                    sew     <= vtype_nxt[5:3];
                    vma     <= vtype_nxt[6];
                    vta     <= vtype_nxt[7];
                    vill    <= vtype_nxt[XLEN-1];
                end
                // Update AVL directly if using vsetivli
              // TODO: register version, which is more reasonable tbh (5 bits is too small for a vector lol)
                if (cfg_type === 2'b11) begin
                    avl     <= src_1;
                end
            end
        end
    end

    // ---------------------------------------- ALU --------------------------------------------------------------------------------

    // TODO: hold values steady while waiting for multiple register groupings...
  
    // SIGN-EXTENDED IMMEDIATE FOR ALU
    always @(posedge clk) begin
        if (~rst) begin
            reg_count   <= 'h0;
            s_ext_imm_d <= 'h0;
            s_ext_imm_e <= 'h0;
        end else begin
            reg_count <= (reg_count > 0)    ? reg_count - 1
                                            : ((opcode_mjr_d === 7'h57 && opcode_mnr_d == 3'b011 && vlmul > 0) ? vlmul : 0);

            case (alu_req_sew)
                3'h0:     s_ext_imm_d <= {{(DATA_WIDTH-8){1'b0}}, {3{src_1[4]}}, src_1};
                3'h1:     s_ext_imm_d <= {{(DATA_WIDTH-16){1'b0}}, {11{src_1[4]}}, src_1};
                3'h2:     s_ext_imm_d <= {{(DATA_WIDTH-32){1'b0}}, {27{src_1[4]}}, src_1};
                3'h3:     s_ext_imm_d <= {{(DATA_WIDTH-64){1'b0}}, {59{src_1[4]}}, src_1};
                default:  s_ext_imm_d <= 3'h0;
            endcase

            // new simm when its an intermediate input and we aren't mid-instruction
            s_ext_imm_e <= (opcode_mjr_d === 7'h57 && opcode_mnr_d == 3'b011 && reg_count == 0) ? s_ext_imm_d : s_ext_imm_e; // latch value for register groupings
        end
    end

    // ALU INPUTS

    always @(posedge clk) begin
        // enable ALU if ALU op AND ((VR enabled AND valu.vv) OR valu.vi OR valu.vx)
        alu_enable  <= (((vr_en[0][0] || vr_en[1][0]) && (opcode_mnr_d == 3'h0)) || (opcode_mnr_d == 3'b011) || (opcode_mnr_d == 3'b100)) && (opcode_mjr_d === 7'h57);
        alu_req_sew <= sew;
    end

    // ASSIGNING FIRST SOURCE BASED ON OPCODE TYPE (VX vs VI vs VV)
    always_comb begin
        case (opcode_mnr_e[0])
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
    vALU #(.REQ_DATA_WIDTH(DATA_WIDTH), .RESP_DATA_WIDTH(DATA_WIDTH), .REQ_ADDR_WIDTH(ADDR_WIDTH)) alu (.clk(clk), .rst(~rst),
        .req_valid(alu_enable), .req_func_id(funct6_e[0]), .req_sew(alu_req_sew[1:0]), .req_data0(alu_data_in1), .req_data1(alu_data_in2), .req_addr(dest),
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
    assign en_vs1 = (opcode_mjr === 7'h57 && opcode_mnr >= 3'h0 && opcode_mnr <= 3'h2);

    // used for all ALU and one each of load/store
    assign en_vs2 = (opcode_mjr === 7'h57 && opcode_mnr !== 3'h7 && funct6 !== 'h17) || (opcode_mjr === 7'h7 && mop[0]) || (opcode_mjr === 7'h27 && mop[0]);

    // used for LOAD-FP (m stage) and ALU (wb stage)
    assign en_vd = alu_valid_out;//(opcode_mjr_e === 7'h57 && opcode_mnr_e !== 3'h7); //(opcode_mjr_m == 7'h7) ||

    // lol bro thats not how store works
    // used only for STORE-FP in M stage
    assign en_vs3 = (opcode_mjr_m === 7'h27 && opcode_mnr_m >= 3'h0 && opcode_mnr_m <= 3'h2);


    assign vr_en[0] = {DW_B{~agu_idle[0]}};
    assign vr_en[1] = {DW_B{~agu_idle[1]}};   //rst & en_vs2;
    assign vr_rw[0] = agu_idle[0];
    assign vr_rw[1] = agu_idle[1];

    // FIXME
    assign proc_idle = (opcode_mjr_d === 'h0) && (opcode_mjr_e[0] === 'h0) && (opcode_mjr_w === 'h0);


    // TODO: memory lol
    // could just run load/store in parallel with ALU theoretically

    // --------------------------------------------------- WRITEBACK STAGE LOGIC --------------------------------------------------------------
    always_ff @(posedge clk or negedge rst) begin
        if (~rst) begin
            vr_data_in[2] <= 'h0;
        end else begin
            vr_data_in[2] <= (alu_valid_out === 1'b1) ? alu_data_out : 'hDEADBEEF;
        end
    end

    assign vr_rw[2] = ~agu_idle[2];
    assign vr_en[2] = {DW_B{~agu_idle[2]}}; // TODO: add byte masking


    // -------------------------------------------------- SIGNAL PROPAGATION LOGIC ------------------------------------------------------------
    always_ff @(posedge clk or negedge rst) begin
        if(~rst) begin
            opcode_mjr_d    <= 0;
            opcode_mnr_d    <= 0;
            dest_d          <= 0;
            funct6_d        <= 0;

            opcode_mjr_e[0] <= 0;
            opcode_mnr_e[0] <= 0;
            dest_e[0]       <= 0;
            funct6_e[0]     <= 0;

            opcode_mjr_w    <= 0;
            opcode_mnr_w    <= 0;
            dest_w          <= 0;
            funct6_w        <= 0;
        end else begin
            opcode_mjr_d    <= reg_count === 0 ? opcode_mjr : opcode_mjr_d;
            opcode_mnr_d    <= reg_count === 0 ? opcode_mnr : opcode_mnr_d;
            dest_d          <= reg_count === 0 ? dest : dest_d;
            funct6_d        <= reg_count === 0 ? funct6 : funct6_d;

            opcode_mjr_e[0] <= opcode_mjr_d;
            opcode_mnr_e[0] <= opcode_mnr_d;
            dest_e[0]       <= dest_d;
            funct6_e[0]     <= funct6_d;

            opcode_mjr_w    <= opcode_mjr_e[`ALU_STG-1];
            opcode_mnr_w    <= opcode_mnr_e[`ALU_STG-1];
            dest_w          <= dest_e[`ALU_STG-1];
            funct6_w        <= funct6_e[`ALU_STG-1];
        end
    end


    // Separate ALU stage logic lol
    genvar i;
    generate
        for (i = 1; i < `ALU_STG; i++) begin
            always_ff @(posedge clk or negedge rst) begin
                if(~rst) begin
                    opcode_mjr_e[i] <= 0;
                    opcode_mnr_e[i] <= 0;
                    dest_e[i]       <= 0;
                    funct6_e[i]     <= 0;
                end else begin
                    opcode_mjr_e[i] <= opcode_mjr_e[i-1];
                    opcode_mnr_e[i] <= opcode_mnr_e[i-1];
                    dest_e[i]       <= dest_e[i-1];
                    funct6_e[i]     <= funct6_e[i-1];
                end
            end
        end
    endgenerate

endmodule