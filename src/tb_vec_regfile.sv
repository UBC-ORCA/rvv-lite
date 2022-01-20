module tb_vec_regfile;

reg clk;
reg en;
reg rw;
reg [4:0] addr;
reg [63:0] data_in;
reg [63:0] data_out;

  vec_regfile DUT(.clk(clk), .en(en), .rw(rw), .addr(addr), .data_in(data_in), .data_out(data_out));
  
initial begin
  clk = 0;
  forever begin
    #5 clk <= ~clk;
  end
end

initial begin
  $dumpfile("dump.vcd"); $dumpvars;
  
  addr = 5'b0;
  data_in = 64'hABCDEF0123456789;
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