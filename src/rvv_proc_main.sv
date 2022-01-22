`include "vec_regfile.sv"

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

    reg clk;
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

    // instruction decode block
    always_ff @(posedge clk or negedge rst) begin
        if(~rst) begin
            // general, universal
            opcode  <= 0;
            dest    <= 0;
            src_1   <= 0;
            src_2   <= 0;
            vm      <= 0;
            funct6  <= 0;
            zimm_11 <= 0;
            zimm_10 <= 0;
            mop     <= 0;
            mew     <= 0;
            nf      <= 0;
        end else begin
            // general, universal
            opcode  <= insn_in[31:25];
            dest    <= insn_in[24:20];
            src_1   <= insn_in[16:12];
            src_2   <= insn_in[11:7];

            // vec-alu and vec-mem
            vm      <= insn_in[6];

            // vec-alu
            funct6  <= insn_in[5:0];

            // vec-cfg
            zimm_11 <= insn_in[11:1];
            zimm_10 <= insn_in[11:2];

            // vec-mem
            mop     <= insn_in[5:4];
            mew     <= insn_in[3];
            nf      <= insn_in[2:0];
        end
    end

  vec_regfile #(.VLEN(VLEN), .DATA_WIDTH(DATA_WIDTH), .ADDR_WIDTH(ADDR_WIDTH), .PORTS(REG_PORTS)) vr (.clk(clk), .en(vr_en), .addr(vr_addr), .data_in(vr_data_in), .data_out(vr_data_out));


endmodule