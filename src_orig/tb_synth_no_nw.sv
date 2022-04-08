module tb_synth_no_nw;

//AGU signals

reg clk_r_w = 0;
reg rst_r_w = 0;

//Decoder/Control ----------------
reg [31:0] insns_r;
//--------------------------------

//Main memory --------------------
wire[63:0] mm_data_out_w_w;
wire[63:0] mm_data_in_w_w;

wire[31:0] addr_vld_mm_w_w;
wire[31:0] addr_vst_mm_w_w;

wire[31:0] addr_vld_vrf_w;

wire req_wr_vst_w;
//--------------------------------

reg req_valid_dec_r;
wire req_ready_dec_w_w;

mm mm_ins(
    .clk(clk_r_w),
    .rst(rst_r_w),

    //Inputs and outputs
    //Input data either from ALU or VLD
    .Da(mm_data_out_w_w),
    .Db(mm_data_in_w_w),
    //Address for data A, B and C
    .Aa(addr_vld_mm_w_w),
    .Ab(addr_vst_mm_w_w),

    //AFU res and vld data valid signal
    .req_wr(req_wr_vst_w)
);

reg [31:0] rs1_val = 0;

synth_shell_mw_no_nw syn_ins(
    .clk_r(clk_r_w),
    .rst_r(rst_r_w),
    .insns_r_w(insns_r),
    .rs1_in(rs1_val),

    .dec_vld_in(req_valid_dec_r),
    .req_rdy_dec(req_ready_dec_w_w),

    //MM/ALU stuff
    .addr_vld_mm_w(addr_vld_mm_w_w),
    .mm_data_out_w(mm_data_out_w_w),

    .addr_vst_mm_w(addr_vst_mm_w_w),
    .da_aux(mm_data_in_w_w),
    .wr_vst_w(req_wr_vst_w)
);

//Clock generator
initial begin
    clk_r_w = 1;
    forever begin
        #5 clk_r_w = ~clk_r_w;
    end
end

reg[2:0] vlmul_r = 0;
reg[2:0] vsew_r  = 3'b011;  
reg vma_r = 0;
reg vm_r  = 0;
reg [6:0] opcode_r = 0;
reg [2:0] funct3_r = 3'b111;
reg [5:0] funct6_r = 0;
reg [4:0] vd_r = 0;
reg [4:0] vs1_r = 0;
reg [4:0] vs2_r = 0;

parameter
	LOAD_FP       = 7'b0000111,
    STORE_FP      = 7'b0100111,
    OP_V          = 7'b1010111;

parameter
    OPIVV       = 3'b000,
    OPFVV       = 3'b001,
    OPMVV       = 3'b010,
    OPIVI       = 3'b011,
    OPIVX       = 3'b100,
    OPFVF       = 3'b101,
    OPMVX       = 3'b110,
    OPCFG       = 3'b111;

parameter
    BIT_8       = 3'b000,
    BIT_16      = 3'b001,
    BIT_32      = 3'b010,
    BIT_64      = 3'b011;

initial begin
    integer i;
    integer j;

    #10 rst_r_w = 0;
    #10 rst_r_w = 1;
    #10 rst_r_w = 0;

    #10 rs1_val = 32;
    //vsetvli 64-bit, vl=32
    vsew_r      = BIT_64;      
    opcode_r    = OP_V;
    funct3_r    = OPCFG;
    vd_r        = 0;
    vs1_r       = 0;
    vs2_r       = 0;
    #10;
    wait(req_ready_dec_w_w == 1);
    insns_r = {4'b0000,vma_r,1'b0,vsew_r,vlmul_r,vs1_r,funct3_r,vd_r,opcode_r};
    #10 req_valid_dec_r = 1;
    wait(req_ready_dec_w_w == 0);
    req_valid_dec_r = 0;
    
    #10 rs1_val = 0;
    //vlm v0, rs1
    vsew_r      = BIT_64;      
    opcode_r    = LOAD_FP;
    funct3_r    = OPIVV;
    vm_r        = 0;
    vd_r        = 0;
    vs1_r       = 0;
    vs2_r       = 0;
    #10;
    wait(req_ready_dec_w_w == 1);
    insns_r = {6'b0,vm_r,vs2_r,vs1_r,funct3_r,vd_r,opcode_r};
    #10 req_valid_dec_r = 1;
    wait(req_ready_dec_w_w == 0);
    req_valid_dec_r = 0;


    #10 rs1_val = 32;
    //vld v1, rs1
    vsew_r      = BIT_64;      
    opcode_r    = LOAD_FP;
    funct3_r    = OPIVV;
    vm_r        = 0;
    vd_r        = 1;
    vs1_r       = 0;
    vs2_r       = 0;
    #10;
    wait(req_ready_dec_w_w == 1);
    insns_r = {6'b0,vm_r,vs2_r,vs1_r,funct3_r,vd_r,opcode_r};
    #10 req_valid_dec_r = 1;
    wait(req_ready_dec_w_w == 0);
    req_valid_dec_r = 0;

    #10 rs1_val = 64;
    //vld v2, rs1
    vsew_r      = BIT_64;      
    opcode_r    = LOAD_FP;
    funct3_r    = OPIVV;
    vm_r        = 0;
    vd_r        = 2;
    vs1_r       = 0;
    vs2_r       = 0;
    #10;
    wait(req_ready_dec_w_w == 1);
    insns_r = {6'b0,vm_r,vs2_r,vs1_r,funct3_r,vd_r,opcode_r};
    #10 req_valid_dec_r = 1;
    wait(req_ready_dec_w_w == 0);
    req_valid_dec_r = 0;

    //vadd.vv v3,v2,v1,vm
    #10 rs1_val = 64;
    //vld v2, rs1
    vsew_r      = BIT_64;      
    opcode_r    = OP_V;
    funct3_r    = OPIVV;
    funct6_r    = 6'b000000;
    vm_r        = 1;
    vd_r        = 3;
    vs1_r       = 2;
    vs2_r       = 1;
    #10;
    wait(req_ready_dec_w_w == 1);
    insns_r = {funct6_r,vm_r,vs2_r,vs1_r,funct3_r,vd_r,opcode_r};
    #10 req_valid_dec_r = 1;
    wait(req_ready_dec_w_w == 0);
    req_valid_dec_r = 0;

    //vslte

    //

    //vsetvli
    // #10;
    // wait(req_ready_dec_w_w == 1);
    // insns_r = 32'b000000_011_001_10000_111_00010_1010111;
    // #10 req_valid_dec_r = 1;
    // wait(req_ready_dec_w_w == 0);
    // req_valid_dec_r = 0;
    
    /*//vlm v0,rs1
    #10;
    wait(req_ready_dec_w_w == 1);
    insns_r = 32'b0000000_00000_00000_000_00000_0000111;
    #10 req_valid_dec_r = 1;
    wait(req_ready_dec_w_w == 0);
    req_valid_dec_r = 0;
    
    //vldm.v v2,rs1
    #10;
    wait(req_ready_dec_w_w == 1);
    insns_r = 32'b000000_1_00011_00001_000_00010_0000111;
    #10 req_valid_dec_r = 1;
    wait(req_ready_dec_w_w == 0);
    req_valid_dec_r = 0;*/

    // //vsetvli
    // #10;
    // wait(req_ready_dec_w_w == 1);
    // insns_r = 32'b000000_000_010_10000_111_00010_1010111;
    // #10 req_valid_dec_r = 1;
    // wait(req_ready_dec_w_w == 0);
    // req_valid_dec_r = 0;

    // //vld v3,rs1
    // #10;
    // insns_r = 32'b0000000_00011_00001_000_00011_0000111;
    // wait(req_ready_dec_w_w == 1);
    // req_valid_dec_r = 1;
    // wait(req_ready_dec_w_w == 0);
    // req_valid_dec_r = 0;

    // //vld v2,rs1
    // #10;
    // insns_r = 32'b0000000_00010_00001_000_00010_0000111;
    // wait(req_ready_dec_w_w == 1);
    // req_valid_dec_r = 1;
    // wait(req_ready_dec_w_w == 0);
    // req_valid_dec_r = 0;

    // //vcustom.vv v4,v2,v3
    // #10;
    // wait(req_ready_dec_w_w == 1);
    // req_valid_dec_r = 1;
    // insns_r = 32'b011100_0_00011_00010_000_00100_1010111;
    // wait(req_ready_dec_w_w == 0);
    // req_valid_dec_r = 0;

    /*//vadd.vv v4,v2,v3
    #10;
    wait(req_ready_dec_w_w == 1);
    req_valid_dec_r = 1;
    insns_r = 32'b0000000_00011_00010_000_00100_1010111;
    wait(req_ready_dec_w_w == 0);
    req_valid_dec_r = 0;

    //vadd.vv v5,v2,v4
    #10;
    wait(req_ready_dec_w_w == 1);
    req_valid_dec_r = 1;
    insns_r = 32'b0000000_00100_00010_000_00101_1010111;
    wait(req_ready_dec_w_w == 0);
    req_valid_dec_r = 0;

    //vst v3,rs1
    #10;
    insns_r = 32'b0000000_00011_00001_000_00011_0100111;
    wait(req_ready_dec_w_w == 1);
    req_valid_dec_r = 1;
    wait(req_ready_dec_w_w == 0);
    req_valid_dec_r = 0;*/


    
    //#1000 $exit;
end

endmodule
