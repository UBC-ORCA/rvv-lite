module tb_vec_regfile;

parameter VLEN_B = 64;
parameter DATA_WIDTH = 64;
parameter ADDR_WIDTH = 5;
parameter PORTS = 2;
parameter DW_B = DATA_WIDTH/8;

reg clk;
reg rst;
reg [7:0] en [PORTS-1:0];
reg rw [PORTS-1:0];
reg [ADDR_WIDTH-1:0] addr [PORTS-1:0];
reg [DATA_WIDTH-1:0] data_in [PORTS-1:0];
reg [DATA_WIDTH-1:0] data_out [PORTS-1:0];
  
  // debug signals
  reg [DATA_WIDTH-1:0] data_in_0;
  reg [DATA_WIDTH-1:0] data_in_1;
  reg [DATA_WIDTH-1:0] data_out_0;
  reg [DATA_WIDTH-1:0] data_out_1;
  reg [ADDR_WIDTH-1:0] addr_0;
  reg [ADDR_WIDTH-1:0] addr_1;
  reg rw_0;
  reg rw_1;

  vec_regfile #(.VLEN(VLEN_B), .DATA_WIDTH(DATA_WIDTH), .ADDR_WIDTH(ADDR_WIDTH), .PORTS(PORTS)) DUT (.clk(clk), .rst(rst), .en(en), .rw(rw), .addr(addr), .data_in(data_in), .data_out(data_out));
  
assign data_in_0 = data_in[0];
assign data_in_1 = data_in[1];
assign data_out_0 = data_out[0];
assign data_out_1 = data_out[1];
assign addr_0 = addr[0];
assign addr_1 = addr[1];
assign rw_0 = rw[0];
assign rw_1 = rw[1];
  
initial begin
  clk = 0;
  forever begin
    #5 clk <= ~clk;
  end
end

initial begin
  $dumpfile("dump.vcd"); $dumpvars;
    rst = 1'b0;
    for (int i = 0; i < PORTS; i++) begin
      en[i] = 1'b0;
    end
    #20;
    rst=1'b1;
    
    for (int i = 0; i < PORTS; i++) begin
      addr[i] = 'h0;
      data_in[i] = 'hABCDEF0123456789;
      en[i] = {DW_B{1'b1}};
      rw[i] = 1'b1;
    end
    #10;
    for (int i = 0; i < PORTS; i++) begin
      addr[i] = 'h1;
      en[i] = {DW_B{1'b0}};
      data_in[i] = 'h9876543210FEDCBA;
    end
    #10;
    for (int i = 0; i < PORTS; i++) begin
      addr[i] = 'h2;

      data_in[i] = 'hAAAAAAAAAAAAAAAA;
    end
    #10;
    for (int i = 0; i < PORTS; i++) begin
      addr[i] = 'h3;
      data_in[i] = 'hBBBBBBBBBBBBBBBB;
      en[i] = {DW_B{1'b1}};
    end
    #10;
    for (int i = 0; i < PORTS; i++) begin
      en[i] = {DW_B{1'b0}};
    end
  
    #100;

  for (int i = 0; i < PORTS; i++) begin
    assert(DUT.vec_data[addr[i]] == data_in[i])
      else $display("Data mismatch! Got %h, expected %h", data_out[i], data_in[i]);

    en[i] = {DW_B{1'b1}};
    rw[i] = 1'b0;
  end
    #10;
  for (int i = 0; i < PORTS; i++) begin
      en[i] = {DW_B{1'b0}};
  end

    #20;
for (int i = 0; i < PORTS; i++) begin
    assert(data_out[i] == data_in[i])
      else $display("Data mismatch! Got %h, expected %h", data_out[i], data_in[0]);
end
    #100;
  
  $finish;
end
  
endmodule