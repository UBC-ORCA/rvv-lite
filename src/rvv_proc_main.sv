`include "vec_regfile.sv"
`include "insn_decoder.sv"

module rvv_proc_main
#(parameter VLEN = 128,   // vector length in bits
parameter NUM_VEC = 32,     // number of available vector registers
parameter INSN_WIDTH = 32,   // width of a single instruction
parameter DATA_WIDTH = 64
) (
    input clk,
    input rst,

    input [INSN_WIDTH-1:0] insn_in // make this a queue I guess?
);
    parameter ADDR_WIDTH = $clog2(NUM_VEC);
    parameter REG_PORTS = 2;

    reg vr_en [REG_PORTS-1:0];
    reg vr_rw [REG_PORTS-1:0];
    reg [ADDR_WIDTH-1:0] vr_addr [REG_PORTS-1:0];
    reg [VLEN-1:0] vr_data_in [REG_PORTS-1:0];
    reg [VLEN-1:0] vr_data_out [REG_PORTS-1:0];

    // insn decomposition -- mostly general
    reg [6:0] opcode;
    reg [4:0] dest;    // rd, vd, or vs3 -- TODO make better name lol
    reg [4:0] src_1;   // rs1, vs1, or imm/uimm
    reg [4:0] src_2;   // rs2, vs2, or imm -- for mem could be lumop, sumop

    // vmem
    reg [2:0] width;
    reg [1:0] mop;
    reg mew;
    reg [2:0] nf;

    // vcfg
    reg [10:0] zimm_11;
    reg [9:0]  zimm_10;

    // valu
    reg vm;
    reg [5:0] funct6;

    insn_decoder #(.INSN_WIDTH(INSN_WIDTH)) id (.clk(clk), .rst(rst), .insn_in(insn_in), .opcode(opcode), .dest(dest), .src_1(src_1), .src_2(src_2), .width(width), .mop(mop), .mew(mew), .nf(nf),
                                                    .zimm_11(zimm_11), .zimm_10(zimm_10), .vm(vm), .funct6(funct6));

    vec_regfile #(.VLEN(VLEN), .DATA_WIDTH(DATA_WIDTH), .ADDR_WIDTH(ADDR_WIDTH), .PORTS(REG_PORTS)) vr (.clk(clk), .en(vr_en), .addr(vr_addr), .data_in(vr_data_in), .data_out(vr_data_out));


endmodule