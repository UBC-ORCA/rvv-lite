module tb_vec_regfile;

parameter VLEN_B = 128;
parameter DATA_WIDTH = 64;
parameter ADDR_WIDTH = 5;
parameter PORTS = 2;

reg clk;
reg en [PORTS-1:0];
reg rw [PORTS-1:0];
reg [ADDR_WIDTH-1:0] addr [PORTS-1:0];
reg [VLEN_B-1:0] data_in [PORTS-1:0];
reg [VLEN_B-1:0] data_out [PORTS-1:0];

  vec_regfile #(.DATA_WIDTH(DATA_WIDTH), .ADDR_WIDTH(ADDR_WIDTH)) DUT (.clk(clk), .en(en), .rw(rw), .addr(addr), .data_in(data_in), .data_out(data_out));
  
initial begin
  clk = 0;
  forever begin
    #5 clk <= ~clk;
  end
end

initial begin
  $dumpfile("dump.vcd"); $dumpvars;
  
  for (int i = 0; i < PORTS; i++) begin
    addr[i] = 'b0;
    data_in[i] = 'hABCDEF0123456789;
    en[i] = 1'b1;
    rw[i] = 1'b1;
    #10;
    en[i] = 0;
    #100;

    assert(DUT.vec_data[addr[i]] == data_in[i])
      else $display("Data mismatch! Got %h, expected %h", data_out[i], data_in[i]);

    en[i] = 1'b1;
    rw[i] = 1'b0;

    #10;

    en[i] = 0;

    #20;

    assert(data_out[i] == data_in[i])
      else $display("Data mismatch! Got %h, expected %h", data_out[i], data_in[0]);

    #100;
  end
  
  
  $finish;
end
  
endmodule