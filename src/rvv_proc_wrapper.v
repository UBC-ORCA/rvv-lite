module rvv_proc_wrapper
  #(parameter VLEN = 64,   // vector length in bits
    parameter NUM_VEC = 32,     // number of available vector registers
    parameter INSN_WIDTH = 32,   // width of a single instruction
    parameter DATA_WIDTH = 64
) (
    input clk,
    input rst,

    input [INSN_WIDTH-1:0] insn_in, // make this a queue I guess?

    output rvv_idle
);

  rvv_proc_main #(VLEN(VLEN), .NUM_VEC(NUM_VEC), .INSN_WIDTH(INSN_WIDTH), .DATA_WIDTH(DATA_WIDTH)) rvv_proc (.*);

endmodule