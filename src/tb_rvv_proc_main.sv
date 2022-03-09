`define FILE_SIZE 38
`define MEM_SIZE 100
`define VLEN 64
`define INSN_WIDTH 32
`define DATA_WIDTH 64
`define NUM_VEC 32

module tb_rvv_proc_main;

// parameter VLEN = 64;   // vector length in bits
// parameter NUM_VEC = 32;     // number of available vector registers
// parameter INSN_WIDTH = 32;
// parameter DATA_WIDTH = 64; // data port width
// parameter INSN_COUNT = ;

reg clk;
reg rst;
reg [`INSN_WIDTH-1:0] insn_in;
reg [`INSN_WIDTH-1:0] insn_mem[0:`MEM_SIZE-1];

  rvv_proc_main #(.VLEN(`VLEN), .NUM_VEC(`NUM_VEC), .INSN_WIDTH(`INSN_WIDTH), .DATA_WIDTH(`DATA_WIDTH)) DUT (.clk(clk), .rst(rst), .insn_in(insn_in));
  
initial begin
  clk = 0;
  forever begin
    #5 clk <= ~clk;
  end
end

initial begin
  $dumpfile("dump.vcd"); $dumpvars;
  $readmemh("insns.in",insn_mem);
  rst = 0;
  insn_in = 'h0;
  #10;
  
  rst = 1;
  
  for (int i = 0; i < `FILE_SIZE; i++) begin
    insn_in = insn_mem[i];
    #10;
  end
  // Because of timing, we end up using the previous values.
  // For this test, that's intended. Will add dependency checking soon.
  // TODO: fix timing. currently requires NOP because of timing.
//   insn_in = 'h5c0000d7; // v.mv.vv v0, v1
//   #10;
//   insn_in = 'h0; // NOP
//   #10;
//   insn_in = 'h5c008157; // v.mv.vv v1, v2
//   #10;
//   insn_in = 'h0; // NOP
//   #10;
//   insn_in = 'h5c0101d7; // v.mv.vv v2, v3
//   #10;
//   insn_in = 'h0; // NOP
//   #10;
//   insn_in = 'h5c018057; // v.mv.vv v3, v0
//   #10;
//   insn_in = 'h00110257; // v.add.vv v4, v1, v2
//   #10;
//   insn_in = 'h000182d7; // v.add.vv v5, v0, v3
//   #10;
//   insn_in = 'h00428357; // v.add.vv v6, v4, v5
//   #10;
//   insn_in = 'h0; // NOP -- resets pipeline
  #100;
  
  $finish;
end
  
endmodule