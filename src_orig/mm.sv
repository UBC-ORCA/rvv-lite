module mm #(
    parameter N_VEC = 31,
    parameter VLMAX = 31,
    parameter ADDR_WIDTH = 31,
    parameter DATA_WIDTH = 63
) (
    input clk,
    input rst,

    //Inputs and outputs
    //Input data either from ALU or VLD
    output reg[DATA_WIDTH:0] Da = 0,
    input [DATA_WIDTH:0] Db,
    //Address for data A, B and C
    input [ADDR_WIDTH:0] Aa,
    input [ADDR_WIDTH:0] Ab,

    //AFU res and vld data valid signal
    input req_wr
);

reg[4:0] state = 0;

parameter 
	ST_WT_REQ       = 5'd1,
    ST_RD_RDY       = 5'd2,
    ST_WR_RDY       = 5'd3;

reg busy = 0;

reg [2047:0][DATA_WIDTH:0] mem_r;

initial begin
    integer i;

    for (i = 1; i <= 2048; i++) 
    begin
        mem_r[i-1] <= 64'hF0_FF_F0_FF_F0_FF_F0_FF;//{8{i[7:0]}};
    end

    // for (i = 0; i < 2048; i++) 
    // begin
    //     mem_r[i] <= 64'hF0_FF_F0_FF_F0_FF_F0_FF;
    // end

    // for (i = 32; i < 64; i++) 
    // begin
    //     mem_r[i] <= 2;
    // end

    // for (i = 64; i < 95; i++) 
    // begin
    //     mem_r[i] <= 3;
    // end
end

always @(posedge clk or posedge rst) begin
    if(req_wr == 1)
    begin
        mem_r[Ab] <= Db;
    end
    Da <= mem_r[Aa];
end
    
endmodule