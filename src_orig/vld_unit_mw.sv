module vld_unit_mw #(
    parameter VLMAX = 31,
    parameter ADDR_WIDTH = 31,
    parameter VREG_WIDTH = 4
) (
    input clk,
    input rst,

    input [4:0] ADDR_IN,
    input [31:0] VL_IN,
    input [VREG_WIDTH:0] VR_IN,
    input [7:0] MASK_IN,
    input [2:0] vsew,

    input [5:0] elem_per_vec,
    input masked,
    input mask_man,
    
    output reg [ADDR_WIDTH:0] addr_out_mm  = 0,
    output reg [ADDR_WIDTH:0] addr_out_vrf = 0,
    output reg [ADDR_WIDTH:0] addr_mask = 0,

    input req_valid,
    output reg req_ready = 0,
    output reg [7:0] b_en = 0,
    output reg req_wr = 0,
    output reg wr_mask = 0,

    input resp_ready,
    output reg resp_valid = 0
);

reg[4:0] state = 0;

parameter 
	ST_WT_REQ       = 5'd1,
    ST_WR_DATA      = 5'd2,
    ST_DONE_RD      = 5'd3;

reg [VREG_WIDTH:0] VR_R = 0;
reg [4:0] BASE_ADDR_MM = 0;
reg [31:0] BASE_ADDR_VRF = 0;
reg [4:0] CNT_R = 0;

reg [31:0] DATA_MM_R;
reg [7:0] byte_mask = 8'b1111_1111;

reg signed [31:0] EVL;
reg signed [31:0] E_CNT;
reg [31:0] VL_IN_R;

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
                    addr_out_mm  <= ADDR_IN;

                    BASE_ADDR_VRF <= VR_IN * VLMAX;
                    addr_out_vrf  <= VR_IN * VLMAX;
                    
                    VL_IN_R <= VL_IN;

                    CNT_R <= CNT_R + 1;

                    req_ready <= 1'b0;
                    resp_valid <= 1'b1;

                    if(mask_man)
                    begin
                        req_wr <= 0;
                        wr_mask <= 1;
                    end
                    else
                    begin
                        req_wr <= 1;
                        wr_mask <= 0;
                    end
                    
                    if(VL_IN < elem_per_vec)
                    begin
                        if(masked)
                        begin
                            b_en <= (byte_mask >> (elem_per_vec-VL_IN)) & MASK_IN;
                        end
                        else
                        begin
                            b_en <= (byte_mask >> (elem_per_vec-VL_IN));
                        end
                        
                        state <= ST_DONE_RD;
                    end
                    else
                    begin
                        EVL <= VL_IN - elem_per_vec;
                        b_en <= byte_mask;
                        E_CNT <= elem_per_vec;
                        state <= ST_WR_DATA;
                    end
                end
            end

            ST_WR_DATA:
            begin
                if(EVL > E_CNT)
                begin
                    resp_valid <= 1;

                    addr_out_vrf <= BASE_ADDR_VRF + CNT_R;
                    addr_out_mm <= BASE_ADDR_MM + CNT_R;

                    if(masked)
                    begin
                        addr_mask <= CNT_R;
                    end
                    
                    CNT_R <= CNT_R + 1;

                    EVL <= EVL - E_CNT;

                    state <= ST_WR_DATA;                    
                end
                else
                begin
                    if(EVL > 31'sd0)
                    begin
                        if(masked)
                        begin
                            b_en <= (byte_mask >> (E_CNT-EVL)) & MASK_IN;
                        end
                        else
                        begin
                            b_en <= byte_mask >> (E_CNT-EVL);
                        end
                        
                        EVL <= 0;
                        resp_valid <= 1;

                        addr_out_vrf <= BASE_ADDR_VRF + CNT_R;
                        addr_out_mm <= BASE_ADDR_MM + CNT_R;
                        if(masked)
                        begin
                            addr_mask <= CNT_R;
                        end
                    
                        CNT_R <= CNT_R + 1;

                        //EVL <= EVL - E_CNT;

                        state <= ST_WR_DATA;
                    end
                    else
                    begin
                        req_wr <= 0;
                        wr_mask <= 0;
                        CNT_R <= 0;
                        req_ready <= 1;
                        resp_valid <= 0;
                        state <= ST_WT_REQ;
                    end
                end
            end

            ST_DONE_RD:
            begin
                b_en <= 0;
                req_wr <= 0;
                wr_mask <= 0;
                CNT_R <= 0;
                req_ready <= 1;
                resp_valid <= 0;
                addr_mask <= 0;
                state <= ST_WT_REQ;
            end

        endcase
    end
end
    
endmodule