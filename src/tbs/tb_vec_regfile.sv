`include "vec_regfile.sv"

module tb_vec_regfile;

    parameter VLEN          = 64;
    parameter DATA_WIDTH    = 64;
    parameter ADDR_WIDTH    = 5;
    parameter PORTS         = 2;
    parameter DW_B          = DATA_WIDTH/8;

    reg                     clk;
    reg                     rst_n;

    reg   [      DW_B-1:0]  vr_rd_en_1;
    reg   [      DW_B-1:0]  vr_rd_en_2;
    reg   [      DW_B-1:0]  vr_wr_en;
    reg   [      DW_B-1:0]  vr_ld_en;
    reg   [      DW_B-1:0]  vr_st_en;
    
    reg                     vr_rd_active_1;
    reg                     vr_rd_active_2;

    reg   [ADDR_WIDTH-1:0]  vr_rd_addr_1;
    reg   [ADDR_WIDTH-1:0]  vr_rd_addr_2;
    reg   [ADDR_WIDTH-1:0]  vr_wr_addr;
    reg   [ADDR_WIDTH-1:0]  vr_ld_addr;
    reg   [ADDR_WIDTH-1:0]  vr_st_addr;

    reg   [      VLEN-1:0]  vr_ld_data_in;
    reg   [      VLEN-1:0]  vr_wr_data_in;

    wire  [      VLEN-1:0]  vr_rd_data_out_1;
    wire  [      VLEN-1:0]  vr_rd_data_out_2;
    wire  [      VLEN-1:0]  vr_st_data_out;

    vec_regfile #(.VLEN(VLEN), .DATA_WIDTH(DATA_WIDTH), .ADDR_WIDTH(ADDR_WIDTH)) vr (.clk(clk),.rst_n(rst_n),
                .rd_en_1(vr_rd_en_1),.rd_en_2(vr_rd_en_2),.wr_en(vr_wr_en),.ld_en(vr_ld_en),.st_en(vr_st_en),
                .rd_addr_1(vr_rd_addr_1),.rd_addr_2(vr_rd_addr_2),.wr_addr(vr_wr_addr),.ld_addr(vr_ld_addr),.st_addr(vr_st_addr),
                .wr_data_in(vr_wr_data_in),.ld_data_in(vr_ld_data_in),.st_data_out(vr_st_data_out),.rd_data_out_1(vr_rd_data_out_1),.rd_data_out_2(vr_rd_data_out_2));

    initial begin
        clk = 0;
        forever begin
            #5 clk <= ~clk;
        end
    end

    initial begin
        $dumpfile("dump.vcd"); $dumpvars;
        rst_n = 1'b0;

        vr_rd_en_1  = {DW_B{1'b0}};
        vr_rd_en_2  = {DW_B{1'b0}};
        vr_wr_en    = {DW_B{1'b0}};
        vr_ld_en    = {DW_B{1'b0}};
        vr_st_en    = {DW_B{1'b0}};

        #20;
        rst_n = 1'b1;

        vr_wr_addr      = 'h0;
        vr_wr_data_in   = 'hABCDEF0123456789;
        vr_wr_en        = {DW_B{1'b1}};

        vr_ld_addr      = 'h3;
        vr_ld_data_in   = 'h9876543210FEDCBA;
        vr_ld_en        = {DW_B{1'b1}};

        #10;
        vr_wr_en        = {DW_B{1'b0}};
        vr_ld_en        = {DW_B{1'b0}};

        vr_rd_addr_1    = 'h3;
        vr_rd_en_1      = {DW_B{1'b1}};

        vr_rd_addr_2    = 'h0;
        vr_rd_en_2      = {DW_B{1'b1}};

        #10;
        vr_rd_en_1      = {DW_B{1'b0}};
        vr_rd_en_2      = {DW_B{1'b0}};

        vr_ld_addr      = 'h2;
        vr_ld_data_in   = 'hAAAAAAAAAAAAAAAA;
        vr_ld_en        = {DW_B{1'b1}};

        #10;
        vr_ld_en        = {DW_B{1'b0}};

        vr_wr_addr      = 'h1;
        vr_wr_data_in   = 'hBBBBBBBBBBBBBBBB;
        vr_wr_en        = {DW_B{1'b1}};

        vr_st_en        = {DW_B{1'b1}};
        vr_st_addr      = 'h2;

        #10;
        vr_rd_en_1  = {DW_B{1'b0}};
        vr_rd_en_2  = {DW_B{1'b0}};
        vr_wr_en    = {DW_B{1'b0}};
        vr_ld_en    = {DW_B{1'b0}};
        vr_st_en    = {DW_B{1'b0}};

        #100;

        // for (int i = 0; i < PORTS; i++) begin
        //     assert(DUT.vec_data[addr[i]] == data_in[i])
        //         else $display("Data mismatch! Got %h, expected %h", data_out[i], data_in[i]);

        //     en[i] = {DW_B{1'b1}};
        //     rw[i] = 1'b0;
        // end
        #10;
        // for (int i = 0; i < PORTS; i++) begin
        //     en[i] = {DW_B{1'b0}};
        // end

        #20;
        // for (int i = 0; i < PORTS; i++) begin
        //     assert(data_out[i] == data_in[i])
        //         else $display("Data mismatch! Got %h, expected %h", data_out[i], data_in[0]);
        // end
        #100;

        $finish;
    end

endmodule