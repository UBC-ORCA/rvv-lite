module AGU_no_nw #(
    parameter VLMAX = 31,
    parameter ADDR_WIDTH = 31,
    parameter VREG_WIDTH = 31,
    parameter VL_WIDTH = 31
) (
    input clk,
    input rst,

    input [VL_WIDTH:0] VL_IN,
    input [4:0] VR_IN,
    input [2:0] vsew,

    input [5:0] elem_per_vec,
    input masked,
    input [5:0] bytes_per_elem,

    input repeat_addr,

    output reg [ADDR_WIDTH:0] addr_out = 0,
    output reg [ADDR_WIDTH:0] addr_mask = 0,
    input [7:0] MASK_IN,

    input req_valid,
    output reg req_ready = 0,

    output reg [7:0] b_en = 0,

    input resp_ready,
    output reg resp_valid = 0,

    output reg start_v = 0,
    output reg end_v = 0,

    //signals for reduction
    input s_value
    
);

reg[4:0] state = 0;

parameter 
	ST_WT_REQ           = 5'd1,
    ST_WT_RDY           = 5'd2,
    ST_DONE_RD          = 5'd3,
    ST_HOLD_ADDR        = 5'd4,
    ST_S_VALUE          = 5'd5;

reg [31:0] VL_R = 0;
reg [31:0] VR_R = 0;
reg [31:0] BASE_ADDR = 0;
reg [31:0] CNT_R = 0;
reg [31:0] CNT_REP_R = 0;
reg [7:0] byte_mask = 8'b1111_1111;

reg signed [31:0] E_CNT;
reg signed [31:0] EVL;

always @(posedge clk or posedge rst) 
begin
    //resp_valid <= 0;
    start_v <= 0;
    end_v   <= 0;
    if(rst == 1)
    begin
        VL_R    <= 0;
        VR_R    <= 0;
        CNT_R   <= 0;
        addr_out <= 0;
        resp_valid  <= 0;
        addr_mask   <= 0;
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
                    VL_R <= VL_IN;
                    VR_R <= VR_IN;
                    
                    req_ready <= 1'b0;
                    resp_valid <= 1'b1;
                    
                    BASE_ADDR <= VR_IN * VLMAX;
                    addr_out  <= VR_IN * VLMAX;

                    if(VL_IN < elem_per_vec)
                    begin
                        if(masked)
                        begin
                            b_en <= byte_mask & MASK_IN;
                        end
                        else
                        begin
                            b_en <= byte_mask >> (bytes_per_elem*(E_CNT-EVL));
                        end
                        //b_en <= byte_mask >> (bytes_per_elem*(elem_per_vec-VL_IN));
                        start_v <= 1;
                        end_v   <= 1;
                        EVL <= 0;
                    end
                    else
                    begin
                        start_v <= 1;
                        end_v   <= 0;
                        b_en <= byte_mask;
                        E_CNT <= elem_per_vec;     
                        CNT_R <= CNT_R + 1;                   
                        EVL <= VL_IN - elem_per_vec;
                    end

                    if(s_value)
                    begin
                        state <= ST_S_VALUE;
                    end
                    else
                    begin
                        state <= ST_WT_RDY;
                    end

                end else
                begin
                    resp_valid <= 0;
                    state <= ST_WT_REQ;
                end
            end
            ST_WT_RDY:
            begin
                if((resp_ready == 1))
                begin
                    if(EVL > E_CNT)
                    begin                    
                        resp_valid <= 1;

                        addr_out <= BASE_ADDR + CNT_R;

                        CNT_R <= CNT_R + 1;

                        EVL <= EVL - E_CNT;

                        if(masked)
                        begin
                            addr_mask <= CNT_R;
                            b_en <= byte_mask & MASK_IN;
                        end

                        if(repeat_addr)
                        begin
                            state <= ST_HOLD_ADDR;
                        end
                        else
                        begin
                            state <= ST_WT_RDY;
                        end
               
                    end
                    else
                    begin
                        if(EVL > 31'sd0)
                        begin
                            if(masked)
                            begin
                                b_en <= byte_mask & MASK_IN;
                            end
                            else
                            begin
                                b_en <= byte_mask >> (bytes_per_elem*(E_CNT-EVL));
                            end
                            //b_en <= byte_mask >> (bytes_per_elem*(E_CNT-EVL));
                            EVL <= 0;                            
                            resp_valid <= 1;

                            addr_out <= BASE_ADDR + CNT_R;

                            CNT_R <= CNT_R + 1;

                            if(masked)
                            begin
                                addr_mask <= CNT_R;
                            end

                            if(repeat_addr)
                            begin
                                state <= ST_HOLD_ADDR;
                            end
                            else
                            begin
                                state <= ST_WT_RDY;
                            end

                        end
                        else
                        begin
                            CNT_R <= 0;
                            req_ready <= 1;
                            resp_valid <= 0;
                            end_v   <= 0;
                            addr_mask <= 0;
                            state <= ST_WT_REQ;
                        end
                    end
                end
            end

            ST_S_VALUE:
            begin
                if((resp_ready == 1))
                begin
                    if(EVL > E_CNT)
                    begin                    
                        resp_valid <= 1;

                        EVL <= EVL - E_CNT;

                        if(repeat_addr)
                        begin
                            state <= ST_HOLD_ADDR;
                        end
                        else
                        begin
                            state <= ST_WT_RDY;
                        end
               
                    end
                    else
                    begin
                        if(EVL > 31'sd0)
                        begin
                            b_en <= byte_mask >> (bytes_per_elem*(E_CNT-EVL));
                            EVL <= 0;                            
                            resp_valid <= 1;

                            if(repeat_addr)
                            begin
                                state <= ST_HOLD_ADDR;
                            end
                            else
                            begin
                                state <= ST_WT_RDY;
                            end

                        end
                        else
                        begin
                            CNT_R <= 0;
                            req_ready <= 1;
                            resp_valid <= 0;
                            end_v   <= 0;
                            state <= ST_WT_REQ;
                        end
                    end
                end
            end

        endcase
    end
end

endmodule