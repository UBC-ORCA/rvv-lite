module decoder #(
    parameter VLMAX = 31,
    parameter ADDR_WIDTH = 31,
    parameter VREG_WIDTH = 31,
    parameter VL_WIDTH = 31
)(
    input clk,
    input rst,

    //Input data
    input [31:0] rs1,
    input [31:0] rs2,

    //Instruction in
    input [31:0] insns,

    output reg [5:0] FUNCT6 = 0,
    output reg [4:0] VS1 = 0,
    output reg [4:0] VS2 = 0,
    output reg [4:0] VD = 0,
    output reg [4:0] BASE_ADDR = 0,

    //Output control signals and data
    output reg update_vl = 0,
    output reg [31:0] vl_out = 0,

    output reg [63:0] operand_X_I,
    output reg ins_X_I = 0,

    //vtype
    output reg [2:0] vlmul = 0,
    output reg [2:0] vsew = 0,

    output reg [5:0] elem_per_vec_AB,
    output reg [5:0] elem_per_vec_C,

    output reg [5:0] bytes_per_elem_AB,
    output reg [5:0] bytes_per_elem_C,

    output reg repeat_AB = 0,
    output reg repeat_C = 0,

    output reg vma = 0,

    //ALU Data in selector
    
    /* Selects between vector load 
     * or the ALU result as input 
     * to the vector register file
     */

    output reg masked = 0,
    output reg mask_man = 0,
    
    output reg SEL_VLD_RES = 0,

    //Singal for mask read sw_itch
    output reg [1:0] SEL_MASKRD,

    //CFU protocol signals
    input req_valid,
    output reg req_ready = 0,
    output reg resp_valid = 0,

    //Either from VLD or addr generators
    input req_ready_AB,
    input req_ready_vld,

    input resp_valid_AB,
    input resp_valid_C,
    input resp_valid_vld,

    input req_ready_vst,
    output reg req_valid_vst = 0,
    input resp_valid_vst,
    output reg resp_ready_vst = 0,

    output reg req_valid_dec_AB = 0,
    output reg req_valid_vld = 0,

    output reg resp_ready_dec_AB = 0,
    output reg resp_ready_vld = 0,

    input req_ready_C,
    output reg req_valid_dec_C = 0,
    output reg resp_ready_dec_C = 0,

    //Signals for reduction
    output reg s_value_A = 0,

    //Signal for custom insns
    output reg custom_i = 0,

    output reg [1:0] SEL_MASK_RD
);

enum reg[4:0] { 
	ST_WT_REQ           = 5'd1,
    ST_WT_ALU_RDY       = 5'd2,
    ST_WT_VLD_RDY       = 5'd3,
    ST_WT_AB_RDY        = 5'd4,
    ST_WT_C_RDY         = 5'd5,
    ST_RST_RDY          = 5'd6,
    ST_WT_C_RDY_VST     = 5'd7,
    ST_WT_VST_RDY       = 5'd8
} state;

//enum logic { 
//	LOAD_FP       = 7'b0000111,
//    STORE_FP      = 7'b0100111,
//    OP_V = 7'b1010111
//} opcode;

wire [6:0] opcode;

parameter
	LOAD_FP       = 7'b0000111,
    STORE_FP      = 7'b0100111,
    OP_V = 7'b1010111;

//enum logic { 
//	OPIVV       = 3'b000,
//    OPFVV       = 3'b001,
//    OPMVV       = 3'b010,
//    OPIVI       = 3'b011,
//    OPIVX       = 3'b100,
//    OPFVF       = 3'b101,
//    OPMVX       = 3'b110,
//    OPCFG       = 3'b111
//} funct3;

wire [2:0] funct3;

parameter
    OPIVV       = 3'b000,
    OPFVV       = 3'b001,
    OPMVV       = 3'b010,
    OPIVI       = 3'b011,
    OPIVX       = 3'b100,
    OPFVF       = 3'b101,
    OPMVX       = 3'b110,
    OPCFG       = 3'b111;

assign opcode = insns[6:0];
assign funct3 = insns[14:12];

always @(posedge clk or posedge rst) 
begin
    if(rst == 1)
    begin
        req_ready   <= 1;
        resp_valid  <= 0;
        masked      <= 0;
        mask_man    <= 0;
        s_value_A   <= 0;
        SEL_MASK_RD <= 2'b00;
        state       <= ST_WT_REQ;
    end
    else
    begin
        case (state)
            ST_WT_REQ:
            begin
                if((req_ready == 1) & (req_valid == 1))
                begin                    
                    FUNCT6 <= insns[31:26];
                    VS1  <= insns[19:15];
                    VS2  <= insns[24:20];
                    //VD for both VLD and ALU
                    VD <= insns[11:7];
                    masked <= insns[25];


                    BASE_ADDR <= rs1;

                    req_ready  <= 1'b0;

                    resp_valid <= 1;

                    case (opcode)
                        OP_V:
                        begin
                            if(insns[25] == 1)
                            begin
                                SEL_MASK_RD <= 2'b11;
                            end                            

                            case (funct3)
                                OPCFG:
                                begin
                                    vlmul <= insns[22:20];
                                    vsew  <= insns[25:23];
                                    vma   <= insns[7];
                                    state <= ST_RST_RDY;

                                    repeat_AB <= 0;
                                    repeat_C  <= 0;

                                    casex (insns[31:30])
                                        2'b0?: 
                                        begin
                                            vl_out <= rs1;
                                        end
                                        2'b11: 
                                        begin
                                            vl_out <= {21'd0,insns[29:20]};
                                        end
                                        2'b10: 
                                        begin
                                            vl_out <= {20'd0,insns[30:20]};
                                        end 
                                    endcase

                                    case (insns[25:23])
                                        0:
                                        begin
                                            elem_per_vec_AB     <= 8;
                                            bytes_per_elem_AB   <= 1;

                                            elem_per_vec_C      <= 8;
                                            bytes_per_elem_C    <= 1; 
                                        end
                                        1:
                                        begin
                                            elem_per_vec_AB     <= 4;
                                            bytes_per_elem_AB   <= 2;

                                            elem_per_vec_C      <= 4;
                                            bytes_per_elem_C    <= 2;
                                        end
                                        2:
                                        begin
                                            elem_per_vec_AB     <= 2;
                                            bytes_per_elem_AB   <= 4;

                                            elem_per_vec_C      <= 2;
                                            bytes_per_elem_C    <= 4;
                                        end
                                        3:
                                        begin
                                            elem_per_vec_AB     <= 1;
                                            bytes_per_elem_AB   <= 8;

                                            elem_per_vec_C      <= 1;
                                            bytes_per_elem_C    <= 8;
                                        end 
                                    endcase

                                end 
                                OPIVV:
                                begin
                                    SEL_VLD_RES <= 0;
                                    
                                    req_valid_dec_AB <= 1;
                                    resp_ready_dec_AB <= 1;

                                    req_valid_dec_C <= 1;
                                    resp_ready_dec_C <= 1;

                                    state <= ST_WT_AB_RDY;  

                                    casex (insns[31:26])
                                        6'b11????: //widen
                                        begin
                                            case (bytes_per_elem_AB)
                                                1:
                                                begin
                                                    elem_per_vec_C      <= 4;
                                                    bytes_per_elem_C    <= 2;                                                                                                    
                                                end
                                                2:
                                                begin
                                                    elem_per_vec_C      <= 2;
                                                    bytes_per_elem_C    <= 4;  
                                                end
                                                4:
                                                begin
                                                    elem_per_vec_C      <= 1;
                                                    bytes_per_elem_C    <= 8;  
                                                end
                                            endcase
                                            repeat_AB <= 1;
                                            repeat_C  <= 0;
                                        end
                                        6'b1011??: //narrow
                                        begin
                                            case (bytes_per_elem_AB)
                                                2:
                                                begin
                                                    elem_per_vec_C      <= 8;
                                                    bytes_per_elem_C    <= 1;  
                                                end
                                                4:
                                                begin
                                                    elem_per_vec_C      <= 4;
                                                    bytes_per_elem_C    <= 2;  
                                                end
                                                8:
                                                begin
                                                    elem_per_vec_C      <= 2;
                                                    bytes_per_elem_C    <= 4;  
                                                end
                                            endcase
                                            repeat_AB <= 0;
                                            repeat_C  <= 1;
                                        end
                                        6'b011100: //Custom insns
                                        begin
                                            custom_i <= 1;
                                            repeat_AB <= 0;
                                            repeat_C  <= 0;
                                        end
                                        default:
                                        begin
                                            repeat_AB <= 0;
                                            repeat_C  <= 0;
                                        end 
                                    endcase
                                end
                                OPIVX:
                                begin
                                    operand_X_I <= {32'd0,rs1};
                                    ins_X_I <= 1;

                                    SEL_VLD_RES <= 0;
                                    
                                    req_valid_dec_AB <= 1;
                                    resp_ready_dec_AB <= 1;

                                    req_valid_dec_C <= 1;
                                    resp_ready_dec_C <= 1;

                                    state <= ST_WT_AB_RDY;  
                                end
                                OPIVI:
                                begin
                                    operand_X_I <= {27'd0,insns[24:20]};
                                    ins_X_I <= 1;

                                    SEL_VLD_RES <= 0;
                                    
                                    req_valid_dec_AB <= 1;
                                    resp_ready_dec_AB <= 1;

                                    req_valid_dec_C <= 1;
                                    resp_ready_dec_C <= 1;

                                    state <= ST_WT_AB_RDY;  
                                end
                                OPMVV:
                                begin
                                    //If less than 7, it's a reduction instruction
                                    SEL_VLD_RES <= 0;
                                    
                                    req_valid_dec_AB <= 1;
                                    resp_ready_dec_AB <= 1;

                                    req_valid_dec_C <= 1;
                                    resp_ready_dec_C <= 1;

                                    state <= ST_WT_AB_RDY;

                                    if(FUNCT6 < 7)
                                    begin
                                        s_value_A <= 1;    
                                    end
                                end
                                OPMVX:
                                begin
                                    operand_X_I <= {32'd0,rs1};
                                    ins_X_I <= 1;

                                    SEL_VLD_RES <= 0;
                                    
                                    req_valid_dec_AB <= 1;
                                    resp_ready_dec_AB <= 1;

                                    req_valid_dec_C <= 1;
                                    resp_ready_dec_C <= 1;

                                    state <= ST_WT_AB_RDY;  
                                end
                                //Floating point
                                OPFVV:
                                begin
                                end                                                               
                                OPFVF:
                                begin
                                end
                                
                                
                            endcase
                        end
                        LOAD_FP:
                        begin
                            // if (insns[11:7] == 0)
                            // begin
                            //     mask_man <= 1;
                            //     elem_per_vec_AB     <= 8;
                            //     bytes_per_elem_AB   <= 1;

                            //     elem_per_vec_C      <= 8;
                            //     bytes_per_elem_C    <= 1;
                            // end
                            // else
                            // begin
                                 
                            // end

                            if (insns[11:7] == 0)
                            begin
                                mask_man <= 1;
                            end
                            else
                            begin
                                if(insns[25] == 1)
                                begin
                                    SEL_MASK_RD <= 2'b01; 
                                end                                   
                            end

                             
                            

                            SEL_VLD_RES <= 1;
                            req_valid_vld <= 1;
                            resp_ready_vld <= 1;
                            state <= ST_WT_C_RDY;     
                        end 
                        STORE_FP:
                        begin
                            if (insns[11:7] == 0)
                            begin
                                mask_man <= 1;
                                SEL_MASK_RD <= 2'b10; 
                            end
                            SEL_VLD_RES <= 1;
                            req_valid_vst <= 1;
                            resp_ready_vst <= 1;
                            state <= ST_WT_C_RDY_VST;     
                        end 
                        default:
                        begin
                            state <= ST_WT_REQ;
                        end 
                    endcase

                end else
                begin
                    resp_valid <= 0;
                    state <= ST_WT_REQ;
                end
            end
            ST_WT_AB_RDY:
            begin
                state <= ST_WT_ALU_RDY;
            end
            ST_WT_C_RDY:
            begin
                req_valid_vld <= 0;
                state <= ST_WT_VLD_RDY;
            end
            ST_WT_C_RDY_VST:
            begin
                req_valid_vld <= 0;
                state <= ST_WT_VST_RDY;
            end
            ST_RST_RDY:
            begin
                resp_valid <= 0;
                req_ready  <= 1'b1;
                state <= ST_WT_REQ;
            end
            ST_WT_ALU_RDY:
            begin
                if(((req_ready_AB == 1) & (resp_valid_AB == 0)) & ((req_ready_C == 1) & (resp_valid_C == 0)))
                begin
                    resp_valid <= 0;
                    resp_ready_dec_AB <= 0;
                    req_valid_dec_AB <= 0;
                    resp_ready_dec_C <= 0;
                    req_valid_dec_C <= 0;
                    req_ready  <= 1'b1;
                    custom_i <= 0;
                    state <= ST_WT_REQ;
                end
                else
                begin
                    req_valid_dec_C <= 0;
                    req_valid_dec_AB <= 0;
                    s_value_A        <= 0;
                    state <= ST_WT_ALU_RDY;
                end
            end
            ST_WT_VLD_RDY:
            begin
                if((req_ready_vld == 1) & (resp_valid_vld == 0))
                begin
                    resp_valid <= 0;
                    resp_ready_vld <= 0;
                    req_valid_vld <= 0;
                    req_ready  <= 1'b1;
                    mask_man     <= 0;
                    state <= ST_WT_REQ;
                end
                else
                begin
                    state <= ST_WT_VLD_RDY;
                end
            end
            ST_WT_VST_RDY:
            begin
                if((req_ready_vst == 1) & (resp_valid_vst == 0))
                begin
                    resp_valid <= 0;
                    resp_ready_vst <= 0;
                    req_valid_vst <= 0;
                    req_ready  <= 1'b1;
                    mask_man     <= 0;
                    state <= ST_WT_REQ;
                end
                else
                begin
                    state <= ST_WT_VST_RDY;
                end
            end
        endcase
    end
end

endmodule