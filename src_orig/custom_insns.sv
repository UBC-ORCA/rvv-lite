module custom_insns
(
    input clk,
    input rst,
    input[63:0] c_in1,
    input[63:0] c_in2,
    input req_vld,
    input [31:0] req_addr,
    input [7:0] req_be,

    output reg [63:0] rsp_res,
    output reg req_rdy = 0,
    output reg rsp_vld = 0,
    output reg [31:0] rsp_addr = 0,
    output reg [7:0] rsp_be = 0,
    output reg word_dword = 0
);

always @(posedge clk or posedge rst) 
begin
    if(rst == 1)
    begin
        req_rdy     <= 1;
        rsp_vld     <= 0;
        rsp_addr    <= 0;
        rsp_res     <= 0;
        rsp_be      <= 0;
    end
    else
    begin

        if(c_in1 >= c_in2)
        begin
            rsp_res <= c_in1 - c_in2;
        end
        else
        begin
            rsp_res <= c_in2 - c_in1;
        end
        rsp_vld <= req_vld;
        rsp_addr <= req_addr;
        rsp_be <= req_be;
        // rsp_res <= c_in1 + c_in2;
    end
end

endmodule
