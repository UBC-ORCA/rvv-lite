`define FILE_SIZE 20
`define MEM_SIZE 100
`define VLEN 64
`define INSN_WIDTH 32
`define DATA_WIDTH 64
`define MEM_ADDR_WIDTH 5
`define NUM_VEC 32

module tb_rvv_proc_main;

reg                     clk;
reg                     rst_n;
logic [`INSN_WIDTH-1:0] insn_in;
logic                   insn_valid;
reg   [`INSN_WIDTH-1:0] insn_mem    [0:`MEM_SIZE-1];
reg proc_ready;
  
// Mock memory for now
logic [    `DATA_WIDTH-1:0] mem_port_in;
logic                       mem_port_valid_in;
logic                       mem_port_ready_out;
logic [    `DATA_WIDTH-1:0] mem_port_out;
logic [`MEM_ADDR_WIDTH-1:0] mem_port_addr_out;
logic                       mem_port_valid_out;
  
integer unsigned            idx;
integer unsigned            t;

  rvv_proc_main #(.VLEN(`VLEN), .NUM_VEC(`NUM_VEC), .INSN_WIDTH(`INSN_WIDTH), .DATA_WIDTH(`DATA_WIDTH), .MEM_ADDR_WIDTH(`MEM_ADDR_WIDTH))
            DUT ( .clk(clk), .rst_n(rst_n), .insn_in(insn_in), .mem_port_in(mem_port_in), .mem_port_valid_in(mem_port_valid_in),
                  .mem_port_ready_out(mem_port_ready_out), .mem_port_out(mem_port_out), .mem_port_addr_out(mem_port_addr_out),
                  .mem_port_valid_out(mem_port_valid_out), .proc_rdy(proc_ready), .insn_valid(insn_valid));
  
initial begin
  clk = 0;
  forever begin
    #5 clk <= ~clk;
  end
end

assign insn_in = insn_mem[idx];
assign while_cond = (idx < `FILE_SIZE - 1);
  
initial begin
  $dumpfile("dump.vcd"); $dumpvars;
  $readmemh("insns.in",insn_mem);
  rst_n = 0;
  t = 0;
  idx = 0;
  
  mem_port_in = 'hABCDEF012;
  mem_port_valid_in = 1'b1;
  #10;
  
  rst_n = 1;
  insn_valid = 1;
  // current latency is 8 cycles, lets work on reducing this maybe? or find a way to stall the pipeline so we don't have to put NOP in the test file
  #10;
  
  while (while_cond) begin
    t = t + 1;
    
    idx = proc_ready ? idx + 1 : idx; // latch if processor is stalling WHY IS THIS AN INFINITE LOOP


    #10;
  end
  // Because of timing, we end up using the previous values.
  // For this, that's fine. Will add dependency checking soon.
  // TODO: fix timing. currently requires NOP because of timing.

  insn_valid = 0;

  #100;
  
  $finish;
end
  
endmodule