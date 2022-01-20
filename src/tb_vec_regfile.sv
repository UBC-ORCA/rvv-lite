module tb_vec_regfile;

parameter VLEN_B = 128;
parameter ADDR_WIDTH = 5;

reg clk;
reg en;
reg rw;
reg [ADDR_WIDTH-1:0] addr;
reg [VLEN_B-1:0] data_in;
reg [VLEN_B-1:0] data_out;

  vec_regfile #(.DATA_WIDTH(VLEN_B), .ADDR_WIDTH(ADDR_WIDTH)) DUT (.clk(clk), .en(en), .rw(rw), .addr(addr), .data_in(data_in), .data_out(data_out));
  
initial begin
  clk = 0;
  forever begin
    #5 clk <= ~clk;
  end
end

initial begin
  $dumpfile("dump.vcd"); $dumpvars;
  
  addr = 'b0;
  data_in = 'hABCDEF0123456789;
  en = 1'b1;
  rw = 1'b1;
  #10;
  en = 0;
  #100;
  
  assert(DUT.vec_data[addr] == data_in)
    else $display("Data mismatch! Got %h, expected %h", data_out, data_in);
  
  en = 1'b1;
  rw = 1'b0;
  
  #10;
  
  en = 0;
  
  #20;
  
  assert(data_out == data_in)
    else $display("Data mismatch! Got %h, expected %h", data_out, data_in);
  
  #100;
  
  
  $finish;
end
  
endmodule