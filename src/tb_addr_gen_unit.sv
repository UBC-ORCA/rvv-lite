module tb_addr_gen_unit;

parameter ADDR_WIDTH = 5;

reg clk;
reg rst;
reg en;
reg rw;
reg [2:0] vlmul;
reg [ADDR_WIDTH-1:0] addr_in;
reg [ADDR_WIDTH-1:0] addr_out;
wire agu_idle;

  addr_gen_unit #(.ADDR_WIDTH(ADDR_WIDTH)) DUT (.clk(clk), .rst(rst), .en(en), .vlmul(vlmul), .addr_in(addr_in), .addr_out(addr_out), .idle(agu_idle));
  
initial begin
  clk = 0;
  forever begin
    #5 clk <= ~clk;
  end
end

initial begin
    $dumpfile("dump.vcd"); $dumpvars;
    rst = 1'b0;
    #10;
    rst = 1'b1;
  
    en = 1'b1;
    addr_in = 5'h1;
    vlmul = 3'b010;
    wait(~agu_idle);
    wait(agu_idle);
    // test that it doesn't take this input
    addr_in = 5'h3;
    vlmul = 3'b001;
    wait(~agu_idle);
    wait(agu_idle);
    addr_in = 5'h3;
    vlmul = 3'b011;
    wait(~agu_idle);
    wait(agu_idle);
    addr_in = 5'h5;
    vlmul = 3'b000;
    wait(~agu_idle);
    wait(agu_idle);
    addr_in = 5'h5;
    vlmul = 3'b100;
    wait(~agu_idle);
    en = 1'b0;
    wait(agu_idle);
  
  $finish;
end
  
endmodule