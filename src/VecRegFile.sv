module VecRegFile #(
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
    output reg[DATA_WIDTH:0] Db = 0,
    input [DATA_WIDTH:0] Dc,
    //Address for data A, B and C
    input [ADDR_WIDTH:0] Aa,
    input [ADDR_WIDTH:0] Ab,
    input [ADDR_WIDTH:0] Ac,

    //CFU protocol signals
    //AGU valid signals
    input req_validAddrA,
    input req_validAddrB,
    input req_validAddrC,

    //AFU res and vld data valid signal
    input req_validDc,

    //Ready to get a read or write request
    //output reg req_ready = 1,
    output reg req_ready = 1,

    input resp_ready,
    output reg resp_valid = 1
);

reg[4:0] state = 0;

parameter 
	ST_WT_REQ       = 5'd1,
    ST_RD_RDY       = 5'd2,
    ST_WR_RDY       = 5'd3;

reg busy = 0;

reg [N_VEC*VLMAX:0][DATA_WIDTH:0] vecRegs;

//wire req_rd;
wire req_wr;

//assign req_rd = (req_validAddrA & req_validAddrB);
//assign req_wr = (req_validAddrC & req_validDc);
assign req_wr = req_validDc;

//assign req_ready = ((req_validAddrA | req_validAddrB) & !req_validAddrC & !busy) | (!req_validAddrA & !req_validAddrB & req_validAddrC & req_validDc & !busy);

//assign req_ready = resp_ready;

always @(posedge clk) begin
    if(req_wr == 1)
    begin
        vecRegs[Ac] <= Dc;
    end
    Da <= vecRegs[Aa];
    Db <= vecRegs[Ab];
end

/*always @(posedge clk or posedge rst) 
begin
    resp_valid <= 0;
    if(rst == 1)
    begin
        resp_valid  <= 0;
        req_ready <= 1;
        state   <= ST_WT_REQ;        
    end
    else
    begin
        case (state)
            ST_WT_REQ:
            begin
                if(req_ready == 1)
                begin
                    if(req_rd == 1)
                    begin
                        req_ready <= 0;
                        state <= ST_RD_RDY;
                    end else
                    begin
                        if (req_wr == 1) 
                        begin
                            req_ready <= 0;
                            state <= ST_WR_RDY;
                        end
                    end
                end
                else
                begin
                    resp_valid <= 0;
                    state <= ST_WT_REQ;
                end
            end
            ST_RD_RDY:
            begin
                if((resp_ready == 1))
                begin
                    resp_valid <= 1;
                    req_ready <= 1;

                    Da <= vecRegs[Aa];
                    Db <= vecRegs[Ab];
                    
                    state <= ST_WT_REQ;
                end
                else
                begin
                    state <= ST_RD_RDY;
                end
            end
            ST_WR_RDY:
            begin
                if((resp_ready == 1))
                begin
                    resp_valid <= 1;
                    req_ready <= 1;

                    vecRegs[Ac] <= Dc;
                    
                    state <= ST_WT_REQ;
                end
                else
                begin
                    state <= ST_WR_RDY;
                end
            end
        endcase
    end
end*/
    
endmodule