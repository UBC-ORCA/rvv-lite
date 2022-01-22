module tb_rvv_proc_main;

parameter VLEN_B = 128;   // vector length in bits
parameter NUM_VEC = 32;     // number of available vector registers
parameter INSN_WIDTH = 32;
parameter DATA_WIDTH = 64; // data port width

reg clk;
reg rst;
reg [INSN_WIDTH-1:0] insn_in;

  rvv_proc_main #(.VLEN_B(VLEN_B), .NUM_VEC(NUM_VEC), .INSN_WIDTH(INSN_WIDTH), .DATA_WIDTH(DATA_WIDTH)) DUT (.clk(clk), .rst(rst), .insn_in(insn_in));
  
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

  insn_in = 'h00000000;
  #100;
  
  insn_in = 'habcef012;
  
  #100;
  
  insn_in = 'h98765432;
  
  #100;
  
  $finish;
end
  
endmodule