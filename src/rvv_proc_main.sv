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
    parameter REG_PORTS = 3;

    reg vr_en [REG_PORTS-1:0];
    reg vr_rw [REG_PORTS-1:0];
    reg [ADDR_WIDTH-1:0] vr_addr [REG_PORTS-1:0];
    reg [VLEN-1:0] vr_data_in [REG_PORTS-1:0];
    reg [VLEN-1:0] vr_data_out [REG_PORTS-1:0];

    // insn decomposition -- mostly general
    // realistically these shouldn't be registered but it makes it easier for now
    reg [6:0] opcode_mjr;
    reg [2:0] opcode_mnr;
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

    insn_decoder #(.INSN_WIDTH(INSN_WIDTH)) id (.clk(clk), .rst(rst), .insn_in(insn_in), .opcode_mjr(opcode_mjr), .opcode_mnr(opcode_mnr), .dest(dest), .src_1(src_1), .src_2(src_2),
                                                .width(width), .mop(mop), .mew(mew), .nf(nf), .zimm_11(zimm_11), .zimm_10(zimm_10), .vm(vm), .funct6(funct6));

    // TODO: add normal regfile? connect to external one? what do here

    vec_regfile #(.VLEN(VLEN), .DATA_WIDTH(DATA_WIDTH), .ADDR_WIDTH(ADDR_WIDTH), .PORTS(REG_PORTS)) vr (.clk(clk), .en(vr_en), .addr(vr_addr), .data_in(vr_data_in), .data_out(vr_data_out));

    // used only for OPIVV, OPFVV, OPMVV
    assign en_vs1 = (opcode_mjr == 6'h57 && opcode_mnr >= 3'b0 && opcode_mnr <= 3'b2);

    // used for all ALU and one each of load/store
    assign en_vs2 = (opcode_mjr == 6'h57 && opcode_mnr != 3'b7) || (opcode_mjr == 6'h7 && mop[0]) || (opcode_mjr == 6'h27 && mop[0]);

    // Read vector sources
    // TODO: add mask read logic
    always_ff @(posedge clk or negedge rst) begin
        if(~rst) begin
            for (unsigned int i = 0; i < 2; i++) begin
                vr_en[i]    <= 0;
            end
        end else begin
            vr_en[0]    <= en_vs1;
            if (en_vs1) begin
                vr_addr[0]  <= src_1;
                vr_rw[0]    <= 0;
            end

            vr_en[1]    <= en_vs2;
            if (en_vs2) begin
                vr_addr[1]  <= src_2;
                vr_rw[1]    <= 0;
            end
        end
    end

    // add cycle delay to destination regs
    always_ff @(posedge clk or negedge rst) begin
        if(~rst) begin
            opcode_mjr_e    <= 0;
            opcode_mnr_e    <= 0;

            opcode_mjr_m    <= 0;
            opcode_mnr_m    <= 0;
        end else begin
            opcode_mjr_e    <= opcode_mjr;
            opcode_mnr_e    <= opcode_mnr;
            dest_e          <= dest;

            opcode_mjr_m    <= opcode_mjr_e;
            opcode_mnr_m    <= opcode_mnr_e;
            dest_m          <= dest_e;
        end
    end

    // TODO: somehow signal that the vectors are ready lol
    // reg rdy_vs1
    // reg rdy_vs2

    // could just run load/store in parallel with ALU theoretically

    // TODO: send logic to ALU!

    // used for LOAD-FP and ALU
    assign en_vd = opcode_mjr_m == 6'h7 || (opcode_mjr_m == 6'h57 && opcode_mnr_m != 3'b7);

    // lol bro thats not how store works
    // used only for STORE-FP
    assign en_vs3 = (opcode_mjr_m == 6'h27 && opcode_mnr_m >= 3'b0 && opcode_mnr_m <= 3'b2);

    // mem_stage
    always_ff @(posedge clk or negedge rst) begin
        if(~rst) begin
            vr_en[2]    <= 0;
        end else begin
            vr_en[2]    <= en_vd || en_vs3;
            if (en_vd) begin
                vr_rw[0]    <= 1;
            end
            if (en_vs3) begin
                vr_rw[0]    <= 0;
            end
        end
    end

    // TODO: writeback logic

endmodule