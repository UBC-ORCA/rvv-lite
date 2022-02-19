module tb_rvv_proc_main;

parameter VLEN = 64;   // vector length in bits
parameter NUM_VEC = 32;     // number of available vector registers
parameter INSN_WIDTH = 32;
parameter DATA_WIDTH = 64; // data port width

reg clk;
reg rst;
reg [INSN_WIDTH-1:0] insn_in;

  rvv_proc_main #(.VLEN(VLEN), .NUM_VEC(NUM_VEC), .INSN_WIDTH(INSN_WIDTH), .DATA_WIDTH(DATA_WIDTH)) DUT (.clk(clk), .rst(rst), .insn_in(insn_in));
  
initial begin
  clk = 0;
  forever begin
    #5 clk <= ~clk;
  end
end

initial begin
  $dumpfile("dump.vcd"); $dumpvars;
  rst = 0;
  #10;
  
  rst = 1;
  // Because of timing, we end up using the previous values.
  // For this test, that's intended. Will add dependency checking soon.
  // TODO: fix timing. currently requires NOP because of timing.
  insn_in = 'h5c0000d7; // v.mv.vv v0, v1
//   #10;
//   insn_in = 'h0; // NOP
  #10;
  insn_in = 'h5c008157; // v.mv.vv v1, v2
//   #10;
//   insn_in = 'h0; // NOP
  #10;
  insn_in = 'h5c0101d7; // v.mv.vv v2, v3
//   #10;
//   insn_in = 'h0; // NOP
  #10;
  insn_in = 'h5c018057; // v.mv.vv v3, v0
  #10;
  insn_in = 'h0; // NOP -- resets pipeline
  #100;
  
  $finish;
end
  
endmodule