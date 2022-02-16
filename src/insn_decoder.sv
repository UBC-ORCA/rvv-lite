module insn_decoder
#(parameter INSN_WIDTH = 32)   // width of a single instruction
    (   input clk,
        input rst,
        input [INSN_WIDTH-1 : 0] insn_in,
        output [6:0] opcode_mjr, // OP-V, LOAD-FP, STR-FP
        output [2:0] opcode_mnr, // CFG=7, other= ALU types
        output [4:0] dest,    // rd, vd, or vs3 -- TODO make better name lol
        output [4:0] src_1,   // rs1, vs1, or imm/uimm
        output [4:0] src_2,   // rs2, vs2, or imm -- for mem could be lumop, sumop

        // vmem
        output [2:0] width,
        output [1:0] mop,
        output mew,
        output [2:0] nf,

        // vcfg
        output [10:0] zimm_11,
        output [9:0]  zimm_10,
        output [1:0] cfg_type,

        // valu
        output vm,
        output [5:0] funct6
    );
  
  assign opcode_mjr = {7{rst}} & insn_in[6:0];
  assign opcode_mnr = {3{rst}} & insn_in[14:12];
  
  assign dest = {5{rst}} & insn_in[11:7];
  assign src_1 = {5{rst}} & insn_in[16:12];
  assign src_2 ={5{rst}} & insn_in[21:17];
  
  assign vm = rst & insn_in[22];
  assign funct6 = {6{rst}} & insn_in[31:26];
  
  assign zimm_11 = {11{rst}} & insn_in[30:20];
  assign zimm_10 = {10{rst}} & insn_in[29:20];
  
  assign mop = {2{rst}} & insn_in[27:26];
  assign mew = rst & insn_in[28];
  assign nf = {3{rst}} & insn_in[31:29];
  
  assign cfg_type = {2{rst}} & insn_in[31:30];

endmodule