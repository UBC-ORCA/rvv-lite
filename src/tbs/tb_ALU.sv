`define DATA_WIDTH  64
`define DW_B        `DATA_WIDTH/8
`define ADDR_WIDTH  5

module tb_ALU;
    reg                               clk           ;
    reg                               rst           ;
    reg                               req_valid     ;
    reg       [                  2:0] req_op_mnr    ;
    reg       [                  5:0] req_func_id   ;
    reg       [                  1:0] req_sew       ;
    reg       [      `DATA_WIDTH-1:0] req_data0     ;
    reg       [      `DATA_WIDTH-1:0] req_data1     ;
    reg       [      `ADDR_WIDTH-1:0] req_addr      ;
    reg       [            `DW_B-1:0] req_be        ;
    reg       [                  7:0] req_vl        ;
    reg       [                 10:0] req_vr_idx    ; // we include this for insns where we need to know index in register groups
    reg                               req_start     ;
    reg                               req_end       ;
    reg                               req_mask      ;
    reg       [                  7:0] req_off       ;
    reg                               req_whole_reg ;
    reg       [                  1:0] req_vxrm      ;
    reg                               resp_valid    ;
    wire                              resp_start    ;
    wire                              resp_end      ;
    wire      [      `DATA_WIDTH-1:0] resp_data     ;
    wire                              req_ready     ;
    wire      [      `ADDR_WIDTH-1:0] req_addr_out  ;
    wire      [                  7:0] resp_off      ;
    wire      [                  7:0] req_vl_out    ;
    wire      [            `DW_B-1:0] req_be_out    ;
    wire                              resp_mask_out ;
    wire                              resp_sca_out  ;
    wire                              resp_whole_reg;  
  
  vALU #(.REQ_DATA_WIDTH(`DATA_WIDTH), .RESP_DATA_WIDTH(`DATA_WIDTH), .REQ_ADDR_WIDTH(`ADDR_WIDTH))
            alu (.clk(clk), .rst(rst), .req_valid(req_valid), .req_mask(req_mask), 
              .req_func_id(req_func_id), .req_sew(req_sew), .req_data0(req_data0), .req_data1(req_data1), .req_addr(req_addr), .req_op_mnr(req_op_mnr),
              .req_be(req_be), .req_sew(req_sew), .req_data0(req_data0), .req_data1(req_data1), .req_addr(req_addr), .req_off(req_off),
        .resp_valid(resp_valid), .resp_data(resp_data), .req_addr_out(req_addr_out), .req_vl(req_vl), .req_vl_out(req_vl_out),
        .resp_mask_out(resp_mask_out), .req_be_out(req_be_out),
        .resp_start(resp_start), .resp_end(resp_end), .resp_off(resp_off), .resp_whole_reg(resp_whole_reg), .resp_sca_out(resp_sca_out));
  
  
  initial begin
    clk = 0;
    forever begin
      #5 clk <= ~clk;
    end
  end

  initial begin
    $dumpfile("dump.vcd"); $dumpvars;
    rst = 1;

    req_func_id = 'h0;
    req_op_mnr  = 'h0;
    req_data1   = 'h0;
    req_data0   = 'h0;
    req_valid   = 'b0;
    req_mask    = 'b1;

    #10;

    rst = 'b0;

    // SSRL 64 bit

    req_func_id = 6'b101000;
    req_op_mnr  = 3'b000;
    req_data1   = 64'hFFFFFFFFFFFFFFFF;
    req_data0   = 64'd32;
    req_valid   = 'b1;
    req_sew   = 2'b11;

    #10;

    req_valid   = 'b0;

    #100;

    $finish;
  end
  
endmodule
  