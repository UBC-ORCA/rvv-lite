module vst_unit #(
    parameter VLMAX = 31,
    parameter ADDR_WIDTH = 31,
    parameter VREG_WIDTH = 4
) (
    input clk,
    input rst,

    input [4:0] ADDR_IN,
    input [4:0] N_DATA_IN,
    input [VREG_WIDTH:0] VR_IN,
    
    output reg [ADDR_WIDTH:0] addr_out_mm  = 0,
    output reg [ADDR_WIDTH:0] addr_out_vrf = 0,

    input req_valid,
    output reg req_ready = 0,
    output reg req_wr = 0,

    input resp_ready,
    output reg resp_valid = 0
);

reg[4:0] state = 0;

parameter 
	ST_WT_REQ       = 5'd1,
    ST_WR_DATA      = 5'd2,
    ST_RD_DATA       = 5'd3;

reg [VREG_WIDTH:0] VR_R = 0;
reg [4:0] BASE_ADDR_MM = 0;
reg [31:0] BASE_ADDR_VRF = 0;
reg [4:0] CNT_R = 0;
reg [4:0] N_DATA_IN_R;
reg [31:0] DATA_MM_R;

always @(posedge clk or posedge rst) 
begin
    //resp_valid <= 0;
    //req_wr <= 0;
    if(rst == 1)
    begin
        VR_R    <= 0;
        CNT_R   <= 0;

        addr_out_mm <= 0;
        addr_out_vrf <= 0;

        resp_valid  <= 0;
        state   <= ST_WT_REQ;
        req_ready <= 1;
    end
    else
    begin
        case (state)
            ST_WT_REQ:
            begin
                if((req_ready == 1) & (req_valid == 1))
                begin
                    VR_R <= VR_IN;

                    BASE_ADDR_MM <= ADDR_IN;
                    N_DATA_IN_R <= N_DATA_IN;
                    addr_out_mm  <= ADDR_IN;

                    BASE_ADDR_VRF <= VR_IN * VLMAX;
                    CNT_R <= CNT_R + 1;
                    addr_out_vrf  <= VR_IN * VLMAX;

                    req_ready <= 1'b0;
                    resp_valid <= 1'b1;

                    req_wr <= 1;

                    state <= ST_WR_DATA;
                end
            end

            ST_WR_DATA:
            begin
                if(CNT_R < N_DATA_IN_R)
                begin
                    resp_valid <= 1;

                    addr_out_vrf <= BASE_ADDR_VRF + CNT_R;
                    addr_out_mm <= BASE_ADDR_MM + CNT_R;
                    
                    CNT_R <= CNT_R + 1;

                    state <= ST_WR_DATA;                    
                end
                else
                begin
                    req_wr <= 0;
                    CNT_R <= 0;
                    req_ready <= 1;
                    resp_valid <= 0;
                    state <= ST_WT_REQ;
                end
            end

            /*ST_WT_REQ:
            begin
                if((req_ready == 1) & (req_valid == 1))
                begin
                    VR_R <= VR_IN;

                    BASE_ADDR_MM <= ADDR_IN;
                    N_DATA_IN_R <= N_DATA_IN;
                    addr_out_mm  <= ADDR_IN;

                    BASE_ADDR_VRF <= VR_IN * VLMAX;
                    addr_out_vrf  <= VR_IN * VLMAX;

                    CNT_R <= CNT_R + 1;

                    req_ready <= 1'b0;
                    resp_valid <= 1'b1;
                    
                    state <= ST_WR_DATA;
                end else
                begin
                    resp_valid <= 0;
                    state <= ST_WT_REQ;
                end
            end
            ST_WR_DATA:
            begin
                state <= ST_RD_DATA;
                req_wr <= 1;
            end
            ST_RD_DATA:
            begin
                if(CNT_R < N_DATA_IN_R)
                begin
                    resp_valid <= 1;

                    addr_out_vrf <= BASE_ADDR_VRF + CNT_R;
                    addr_out_mm <= BASE_ADDR_MM + CNT_R;

                    CNT_R <= CNT_R + 1;
                    state <= ST_WR_DATA;                    
                end
                else
                begin
                    CNT_R <= 0;
                    req_ready <= 1;
                    resp_valid <= 0;
                    state <= ST_WT_REQ;
                end
            end*/
        endcase
    end
end
    
endmodule