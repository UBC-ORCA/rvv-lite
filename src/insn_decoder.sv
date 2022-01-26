module insn_decoder
#(parameter INSN_WIDTH = 32)   // width of a single instruction
    (   input clk,
        input rst,
        input [INSN_WIDTH-1 : 0] insn_in,
        output reg [6:0] opcode_mjr, // OP-V, LOAD-FP, STR-FP
        output reg [2:0] opcode_mnr, // CFG=7, other= ALU types
        output reg [4:0] dest,    // rd, vd, or vs3 -- TODO make better name lol
        output reg [4:0] src_1,   // rs1, vs1, or imm/uimm
        output reg [4:0] src_2,   // rs2, vs2, or imm -- for mem could be lumop, sumop

        // vmem
        output reg [2:0] width,
        output reg [1:0] mop,
        output reg mew,
        output reg [2:0] nf,

        // vcfg
        output reg [10:0] zimm_11,
        output reg [9:0]  zimm_10,

        // valu
        output reg vm,
        output reg [5:0] funct6
    );

    // instruction decode block
    always_ff @(posedge clk or negedge rst) begin
        if(~rst) begin
            // general, universal
            opcode_mjr  <= 0;
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
            opcode_mjr  <= insn_in[6:0];
            opcode_mnr  <= insn_in[14:12];
            dest        <= insn_in[11:7];
            src_1       <= insn_in[16:12];
            src_2       <= insn_in[21:17];

            // vec-alu and vec-mem
            vm      <= insn_in[22];

            // vec-alu
            funct6  <= insn_in[31:26];

            // vec-cfg
            zimm_11 <= insn_in[30:20];
            zimm_10 <= insn_in[29:20];
            cfg_type <= insn_in[31:30]; // 0X = vsetvli, 11 = vsetivli, 10 = vsetvl

            // vec-mem
            mop     <= insn_in[27:26];
            mew     <= insn_in[28];
            nf      <= insn_in[31:29];
        end
    end

endmodule