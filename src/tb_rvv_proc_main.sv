`define FILE_SIZE 10
`define MEM_SIZE 1000
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
reg proc_ready;
  
reg [9:0]   insn_idx;
integer t;

  rvv_proc_main #(.VLEN(`VLEN), .NUM_VEC(`NUM_VEC), .INSN_WIDTH(`INSN_WIDTH), .DATA_WIDTH(`DATA_WIDTH)) DUT (.clk(clk), .rst(rst), .insn_in(insn_in), .proc_rdy(proc_ready));
  
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
  t = 0;
  insn_in = 'h0;
  insn_idx = 'h0;
  #10;
  
  rst = 1;
  t = t + 1;
  
  // current latency is 8 cycles, lets work on reducing this maybe? or find a way to stall the pipeline so we don't have to put NOP in the test file
  
  while (insn_idx < `FILE_SIZE && t < 20) begin
    insn_in = insn_mem[insn_idx];
    #5;
    insn_idx = proc_ready ? insn_idx + 1 : insn_idx; // latch if processor is stalling
    #5;
    t = t + 1;
  end
  // Because of timing, we end up using the previous values.
  // For this, that's fine. Will add dependency checking soon.
  // TODO: fix timing. currently requires NOP because of timing.

  #100;
  
  $finish;
end
  
endmodule