parameter VLMAX64 = 32;

module synth_shell_mw(
    input clk_r,
    input rst_r,
    input [31:0] insns_r_w,
    input [31:0] rs1_in,

    input  dec_vld_in,
    output req_rdy_dec,

    //MM/ALU stuff
    output [31:0] addr_vld_mm_w,
    input [63:0] mm_data_out_w,

    output [31:0] addr_vst_mm_w,
    output [63:0] da_aux,
    output wr_vst_w
);

reg [31:0] vl_r = 0;
reg [31:0] vr_a_r = 0;
reg [31:0] vr_b_r = 0;
reg [31:0] vr_c_r = 0;

wire resp_valid_A_w;

wire start_v_w;
wire end_v_w;

wire [31:0] Ac_w;

wire [63:0] Da_w;
wire [63:0] Db_w;
wire [63:0] Dc_w;
wire [63:0] Dout_Alu_C;
reg  [63:0] Dc_r = 0;

assign da_aux = Da_w;

//reg sel_c = 1;

wire sel_vld_res_w;

reg req_validDc_ALU_RF_r = 0;
wire req_validDc_ALU_RF_w;

wire req_ready_C_w;

//wire resp_ready_rf_w;

//assign resp_ready_rf_w = resp_ready_A_w & resp_ready_B_w & resp_ready_C_w;

reg resp_ready_alu_rf_r = 0;

reg resp_valid_C_r = 0;

reg resp_ready_r = 0;

wire req_valid_dec_AB_w;
wire req_valid_dec_C_w;

//AGU A --------------------------
wire [31:0] addr_out_A_w;
reg req_valid_CTRL_AGU_A_r = 0;
reg req_ready_AGU_A_CTRL_w;
wire req_valid_dec_A_w;
//--------------------------------

//AGU B --------------------------
wire [31:0] addr_out_B_w;
reg req_valid_CTRL_AGU_B_r = 0;
reg req_ready_AGU_B_CTRL_w;
wire req_valid_dec_B_w;
wire resp_valid_B_w;
//--------------------------------

//AGU C --------------------------
wire [31:0] addr_out_C_w;
reg req_valid_CTRL_AGU_C_r = 1;
reg req_ready_AGU_C_CTRL_w;

wire resp_valid_C_w;
//--------------------------------

//Decoder/Control ----------------
reg [31:0] sew_r;

wire [5:0] opcode_w;
wire [4:0] vs1_w;
wire [4:0] vs2_w;
wire [4:0] vd_w;
wire [4:0] vld_addr_w;

wire update_vl_w;
wire [31:0] vl_out_w;

wire req_valid_dec_w;
wire req_ready_dec_w;

wire req_ready_AB_dec_w;
wire req_ready_C_dec_w;
wire resp_valid_dec_w;

wire resp_valid_AB;
wire req_valid_dec_vld_w;

wire resp_ready_dec_AB_w;
wire resp_ready_dec_C_w;

wire [5:0] elem_per_vec_AB_w;
wire [5:0] bytes_per_elem_AB_w;

wire [5:0] elem_per_vec_C_w;
wire [5:0] bytes_per_elem_C_w;

wire repeat_AB_w;
wire repeat_C_w;
//--------------------------------

//Main memory --------------------

wire[31:0] addr_vld_vrf_w;

wire req_rdy_vld_w;
wire req_wr_vld_mm;
wire req_wr_vld_vrf;
//--------------------------------

//ALU-----------------------------
wire [31:0] Addr_alu_c_vrf;
//--------------------------------

//VLD-----------------------------
wire resp_ready_vld_w;
wire resp_valid_vld_w;
wire resp_ready_dec_vld_w;
//--------------------------------

//ALU-----------------------
wire [7:0] req_vl_out_w;
wire [7:0] req_be_out_alu_c_w;
wire resp_valid_alu_c_w;

wire req_vld_dec_alu_c;

wire req_rdy_alu_c;

assign req_vld_dec_alu_c = resp_valid_A_w & resp_valid_B_w & resp_valid_C_w;
//--------------------------------

//VST-----------------------------
wire [31:0] addr_rd_A_VRF;
wire [31:0] addr_rd_vst;

wire req_rdy_vst_w;
wire req_valid_dec_vst_w;
wire resp_valid_vst_w;
wire resp_ready_dec_vst_w;

assign addr_rd_A_VRF = (sel_vld_res_w == 1) ? addr_rd_vst : addr_out_A_w;
//--------------------------------

reg req_valid_dec_r = 0;

wire [2:0] vlmul_w;
wire [2:0] vsew_w;
wire vma_w;
wire [7:0] byte_en_w;

wire req_wr_vld_w;

wire [7:0] b_en_w;
wire [7:0] b_en_vld_w;

//---------------------------------

assign req_wr_vld_vrf = (sel_vld_res_w == 1) ? req_wr_vld_w : resp_valid_alu_c_w;

assign Dc_w = (sel_vld_res_w == 1) ? mm_data_out_w:Dout_Alu_C;
assign Ac_w = (sel_vld_res_w == 1) ? addr_vld_vrf_w:Addr_alu_c_vrf;

assign req_ready_AB_dec_w = req_ready_AGU_A_CTRL_w & req_ready_AGU_B_CTRL_w;

assign resp_valid_AB = resp_valid_B_w & resp_valid_A_w;

wire [7:0] b_en_agu_A_w;
wire [7:0] b_en_agu_B_w;
wire [7:0] b_en_agu_C_w;

assign b_en_w = (sel_vld_res_w == 1) ? b_en_vld_w : req_be_out_alu_c_w;

//Masking signals

wire masked_w;
wire mask_man_w;
wire [31:0] addr_out_mask_w;
wire [31:0] addr_ld_mask_w;
wire [7:0] MASK_IN_w;
wire [7:0] b_en_mask_w;

wire [63:0] din_mask;

assign din_mask = (mask_man_w == 1) ? mm_data_out_w : Dout_Alu_C;

//Signals for reduction
wire s_value_A_w;

//Custom instruction signals\
wire custom_i_w;

wire [63:0] dOut_cins;
wire req_rdy_c_agus;
wire rsp_vld_c_reg;
wire [31:0] addr_out_cins;
wire [7:0] b_en_out_c;
wire w_dw_sel;

wire [63:0] dOut_alu;
wire req_rdy_alu;
wire resp_valid_alu_w;
wire [31:0] Addr_alu_vrf;
wire [7:0] req_be_out_alu_w;

assign Dout_Alu_C = (custom_i_w == 1) ? dOut_cins : dOut_alu;
assign req_rdy_alu_c = (custom_i_w == 1) ? req_rdy_c_agus : req_rdy_alu;
assign resp_valid_alu_c_w = (custom_i_w == 1) ? rsp_vld_c_reg : resp_valid_alu_w;
assign Addr_alu_c_vrf = (custom_i_w == 1) ? addr_out_cins : Addr_alu_vrf;
assign req_be_out_alu_c_w = (custom_i_w == 1) ? b_en_out_c : req_be_out_alu_w;

//X/I signals

wire[63:0] dout_mem_2;

wire[63:0] X_I_VAL_W;

wire INS_X_I_W;

assign Db_w = (INS_X_I_W == 1) ? X_I_VAL_W : dout_mem_2;

//Masking signals
wire [1:0] sel_mask_rd_w;
wire [9:0] addr_rd_mask_w;

wire [31:0] addr_st_mask_w;
wire [31:0] addr_agurd_mask_w;

assign addr_rd_mask_w = (sel_mask_rd_w == 2'b01) ? addr_ld_mask_w[9:0] : (sel_mask_rd_w == 2'b10) ? addr_st_mask_w[9:0]: addr_agurd_mask_w[9:0];

AGU agu_A (

    .clk(clk_r),
    .rst(rst_r),

    .VL_IN(vl_out_w),
    .VR_IN(vs1_w),
    .MASK_IN(MASK_IN_w),
    .vsew(vsew_w),
    .addr_out(addr_out_A_w),

    .elem_per_vec(elem_per_vec_AB_w),
    .masked(masked_w),
    .bytes_per_elem(bytes_per_elem_AB_w),

    .repeat_addr(repeat_AB_w),
    
    .req_valid(req_valid_dec_AB_w),
    .req_ready(req_ready_AGU_A_CTRL_w),

    .b_en(b_en_agu_A_w),

    //.resp_ready(req_ready_C_w),
    .resp_ready(resp_ready_dec_AB_w),
    .resp_valid(resp_valid_A_w),
    
    .s_value(s_value_A_w)
);

AGU agu_B (

    .clk(clk_r),
    .rst(rst_r),

    .VL_IN(vl_out_w),
    .VR_IN(vs2_w),
    .MASK_IN(MASK_IN_w),
    .vsew(vsew_w),
    .addr_out(addr_out_B_w),

    .elem_per_vec(elem_per_vec_AB_w),
    .masked(masked_w),
    .bytes_per_elem(bytes_per_elem_AB_w),

    .repeat_addr(repeat_AB_w),
    
    .req_valid(req_valid_dec_AB_w),
    .req_ready(req_ready_AGU_B_CTRL_w),

    .b_en(b_en_agu_B_w),

    //.resp_ready(req_ready_C_w),
    .resp_ready(resp_ready_dec_AB_w),
    .resp_valid(resp_valid_B_w),

    .s_value(0)
);

AGU agu_C (

    .clk(clk_r),
    .rst(rst_r),

    .VL_IN(vl_out_w),
    .VR_IN(vd_w),
    .MASK_IN(MASK_IN_w),
    .vsew(vsew_w),
    .addr_out(addr_out_C_w),

    .elem_per_vec(elem_per_vec_C_w),
    .masked(masked_w),
    .bytes_per_elem(bytes_per_elem_C_w),

    .repeat_addr(repeat_C_w),
    
    .req_valid(req_valid_dec_C_w),
    .req_ready(req_ready_C_dec_w),

    .b_en(b_en_agu_C_w),

    .resp_ready(req_rdy_alu_c),
    .resp_valid(resp_valid_C_w),
    
    .start_v(start_v_w),
    .end_v(end_v_w),
    .s_value(0),

    .addr_mask(addr_agurd_mask_w)
);



vld_unit_mw vld_ins(
    .clk(clk_r),
    .rst(rst_r),

    .ADDR_IN(vld_addr_w),
    .VL_IN(vl_out_w),
    .VR_IN(vd_w),
    .MASK_IN(MASK_IN_w),
    .vsew(vsew_w),

    .elem_per_vec(elem_per_vec_AB_w),

    .masked(masked_w),
    .mask_man(mask_man_w),
    
    .addr_out_mm(addr_vld_mm_w),
    .addr_out_vrf(addr_vld_vrf_w),
    .addr_mask(addr_ld_mask_w),

    .req_valid(req_valid_dec_vld_w),
    .req_ready(req_rdy_vld_w),
    .b_en(b_en_vld_w),
    .req_wr(req_wr_vld_w),
    .wr_mask(wr_mask_w),

    .resp_ready(resp_ready_dec_vld_w),
    .resp_valid(resp_valid_vld_w)
);

vst_unit vst_ins(
    .clk(clk_r),
    .rst(rst_r),

    .ADDR_IN(vld_addr_w),
    .N_DATA_IN(vl_out_w),
    .VR_IN(vd_w),
    
    .addr_out_mm(addr_vst_mm_w),
    .addr_out_vrf(addr_rd_vst),

    .req_valid(req_valid_dec_vst_w),
    .req_ready(req_rdy_vst_w),
    .req_wr(wr_vst_w),

    .resp_ready(resp_ready_dec_vst_w),
    .resp_valid(resp_valid_vst_w)
);

decoder DEC(
    .clk(clk_r),
    .rst(rst_r),

    //Input data
    .rs1(rs1_in),
    .rs2(32'd0),

    //Instruction in
    .insns(insns_r_w),

    .FUNCT6(opcode_w),
    .VS1(vs1_w),
    .VS2(vs2_w),
    .VD(vd_w),
    .BASE_ADDR(vld_addr_w),

    //Output control signals and data
    .update_vl(update_vl_w),
    .vl_out(vl_out_w),

    .operand_X_I(X_I_VAL_W),
    .ins_X_I(INS_X_I_W),

    .vlmul(vlmul_w),
    .vsew(vsew_w),
    
    .elem_per_vec_AB(elem_per_vec_AB_w),
    .bytes_per_elem_AB(bytes_per_elem_AB_w),

    .elem_per_vec_C(elem_per_vec_C_w),
    .bytes_per_elem_C(bytes_per_elem_C_w),

    .repeat_AB(repeat_AB_w),
    .repeat_C(repeat_C_w),

    .vma(vma_w),

    .masked(masked_w),
    .mask_man(mask_man_w),

    //Address generators
    //ALU Data in selector
    
    /* Selects between vector load 
     * or the ALU result as input 
     * to the vector register file
     */
    
    .SEL_VLD_RES(sel_vld_res_w),

    .SEL_MASK_RD(sel_mask_rd_w),

    //CFU protocol signals
    .req_valid(dec_vld_in),
    .req_ready(req_rdy_dec),
    .resp_valid(resp_valid_dec_w),

    //Either from VLD or addr generators
    
    .req_ready_vld(req_rdy_vld_w),
    .req_valid_vld(req_valid_dec_vld_w),
    .resp_valid_vld(resp_valid_vld_w),
    .resp_ready_vld(resp_ready_dec_vld_w),

    .req_ready_vst(req_rdy_vst_w),
    .req_valid_vst(req_valid_dec_vst_w),
    .resp_valid_vst(resp_valid_vst_w),
    .resp_ready_vst(resp_ready_dec_vst_w),

    .req_ready_AB(req_ready_AB_dec_w),
    .req_valid_dec_AB(req_valid_dec_AB_w),
    .resp_valid_AB(resp_valid_AB),
    .resp_ready_dec_AB(resp_ready_dec_AB_w),
    
    .req_ready_C(req_ready_C_dec_w),
    .req_valid_dec_C(req_valid_dec_C_w),
    .resp_valid_C(resp_valid_C_w),
    .resp_ready_dec_C(resp_ready_dec_C_w),

    .s_value_A(s_value_A_w),
    .custom_i(custom_i_w)
);

//VecRegFile VRegFile(
//    .clk(clk_r),
//    .rst(rst_r),

//    //Inputs and outputs
//    //Input/Output data either for ALU and VLD
//    .Da(Da_w),
//    .Db(Db_w),
//    .Dc(Dc_w),
//    //Address for data A, B and C
//    .Aa(addr_rd_A_VRF),
//    .Ab(addr_out_B_w),
//    .Ac(Ac_w),
//    //.Ac(addr_out_C_w),

//    //CFU protocol signals
//    //AGU valid signals
//    .req_validAddrA(resp_valid_A_w),
//    .req_validAddrB(resp_valid_B_w),
//    .req_validAddrC(resp_valid_C_w),

//    //AFU res and vld data valid signal
//    .req_validDc(req_wr_vld_vrf),

//    //Ready to get a read or write request
//    .req_ready(req_ready_C_w),

//    .resp_ready(resp_ready_alu_rf_r),
//    .resp_valid(resp_valid_rf)
//);

asym_ram mask(
    .clkA(clk_r), 
    .clkB(clk_r), 
    .weA(wr_mask_w), 
    .enaA(1), 
    .enaB(1), 
    .addrA(addr_vld_vrf_w[9:0]), 
    .addrB(addr_rd_mask_w), 
    .diA(din_mask), 
    .doB(MASK_IN_w)
);

// wire dbiterra3_w;
// wire sbiterra3_w;

// wire dbiterrb3_w;
// wire sbiterrb3_w;

// wire[63:0] douta3_w;
// wire[63:0] dinb3_w;

//    xpm_memory_tdpram #(
//       .ADDR_WIDTH_A(10),               // DECIMAL
//       .ADDR_WIDTH_B(10),               // DECIMAL
//       .AUTO_SLEEP_TIME(0),            // DECIMAL
//       .BYTE_WRITE_WIDTH_A(8),        // DECIMAL
//       .BYTE_WRITE_WIDTH_B(8),        // DECIMAL
//       .CASCADE_HEIGHT(0),             // DECIMAL
//       .CLOCKING_MODE("common_clock"), // String
//       .ECC_MODE("no_ecc"),            // String
//       .MEMORY_INIT_FILE("none"),      // String
//       .MEMORY_INIT_PARAM("0"),        // String
//       .MEMORY_OPTIMIZATION("true"),   // String
//       .MEMORY_PRIMITIVE("auto"),      // String
//       .MEMORY_SIZE(VLMAX64*8),             // DECIMAL
//       .MESSAGE_CONTROL(0),            // DECIMAL
//       .READ_DATA_WIDTH_A(64),         // DECIMAL
//       .READ_DATA_WIDTH_B(8),         // DECIMAL
//       .READ_LATENCY_A(1),             // DECIMAL
//       .READ_LATENCY_B(1),             // DECIMAL
//       .READ_RESET_VALUE_A("0"),       // String
//       .READ_RESET_VALUE_B("0"),       // String
//       .RST_MODE_A("SYNC"),            // String
//       .RST_MODE_B("SYNC"),            // String
//       .SIM_ASSERT_CHK(0),             // DECIMAL; 0=disable simulation messages, 1=enable simulation messages
//       .USE_EMBEDDED_CONSTRAINT(0),    // DECIMAL
//       .USE_MEM_INIT(1),               // DECIMAL
//       .USE_MEM_INIT_MMI(0),           // DECIMAL
//       .WAKEUP_TIME("disable_sleep"),  // String
//       .WRITE_DATA_WIDTH_A(64),        // DECIMAL
//       .WRITE_DATA_WIDTH_B(8),        // DECIMAL
//       .WRITE_MODE_A("read_first"),     // String
//       .WRITE_MODE_B("read_first"),     // String
//       .WRITE_PROTECT(1)               // DECIMAL
//    )
//    xpm_memory_tdpram_inst3 (
//       .dbiterra(dbiterra3_w),             // 1-bit output: Status signal to indicate double bit error occurrence
//                                        // on the data output of port A.

//       .dbiterrb(dbiterrb3_w),             // 1-bit output: Status signal to indicate double bit error occurrence
//                                        // on the data output of port A.

//       .douta(douta3_w),                   // READ_DATA_WIDTH_A-bit output: Data output for port A read operations.
//       .doutb(MASK_IN_w),                   // READ_DATA_WIDTH_B-bit output: Data output for port B read operations.
//       .sbiterra(sbiterra3_w),             // 1-bit output: Status signal to indicate single bit error occurrence
//                                        // on the data output of port A.

//       .sbiterrb(sbiterrb3_w),             // 1-bit output: Status signal to indicate single bit error occurrence
//                                        // on the data output of port B.

//       .addra(addr_vld_vrf_w[9:0]),                   // ADDR_WIDTH_A-bit input: Address for port A write and read operations.
//       .addrb(addr_ld_mask_w[9:0]),                   // ADDR_WIDTH_B-bit input: Address for port B write and read operations.
//       .clka(clk_r),                     // 1-bit input: Clock signal for port A. Also clocks port B when
//                                        // parameter CLOCKING_MODE is "common_clock".

//       .clkb(clk_r),                     // 1-bit input: Clock signal for port B when parameter CLOCKING_MODE is
//                                        // "independent_clock". Unused when parameter CLOCKING_MODE is
//                                        // "common_clock".

//       .dina(mm_data_out_w),                     // WRITE_DATA_WIDTH_A-bit input: Data input for port A write operations.
//       .dinb(dinb3_w),                     // WRITE_DATA_WIDTH_B-bit input: Data input for port B write operations.
//       .ena(1'b1),                       // 1-bit input: Memory enable signal for port A. Must be high on clock
//                                        // cycles when read or write operations are initiated. Pipelined
//                                        // internally.

//       .enb(1'b1),                       // 1-bit input: Memory enable signal for port B. Must be high on clock
//                                        // cycles when read or write operations are initiated. Pipelined
//                                        // internally.

//       .injectdbiterra(1'b0), // 1-bit input: Controls double bit error injection on input data when
//                                        // ECC enabled (Error injection capability is not available in
//                                        // "decode_only" mode).

//       .injectdbiterrb(1'b0), // 1-bit input: Controls double bit error injection on input data when
//                                        // ECC enabled (Error injection capability is not available in
//                                        // "decode_only" mode).

//       .injectsbiterra(1'b0), // 1-bit input: Controls single bit error injection on input data when
//                                        // ECC enabled (Error injection capability is not available in
//                                        // "decode_only" mode).

//       .injectsbiterrb(1'b0), // 1-bit input: Controls single bit error injection on input data when
//                                        // ECC enabled (Error injection capability is not available in
//                                        // "decode_only" mode).

//       .regcea(1'b1),                 // 1-bit input: Clock Enable for the last register stage on the output
//                                        // data path.

//       .regceb(1'b1),                 // 1-bit input: Clock Enable for the last register stage on the output
//                                        // data path.

//       .rsta(rst_r),                     // 1-bit input: Reset signal for the final port A output register stage.
//                                        // Synchronously resets output port douta to the value specified by
//                                        // parameter READ_RESET_VALUE_A.

//       .rstb(rst_r),                     // 1-bit input: Reset signal for the final port B output register stage.
//                                        // Synchronously resets output port doutb to the value specified by
//                                        // parameter READ_RESET_VALUE_B.

//       .sleep(1'b0),                   // 1-bit input: sleep signal to enable the dynamic power saving feature.
//       .wea(b_en_vld_w),                       // WRITE_DATA_WIDTH_A/BYTE_WRITE_WIDTH_A-bit input: Write enable vector
//                                        // for port A input data port dina. 1 bit wide when word-wide writes are
//                                        // used. In byte-wide write configurations, each bit controls the
//                                        // writing one byte of dina to address addra. For example, to
//                                        // synchronously write only bits [15-8] of dina when WRITE_DATA_WIDTH_A
//                                        // is 32, wea would be 4'b0010.

//       .web(0)                        // WRITE_DATA_WIDTH_B/BYTE_WRITE_WIDTH_B-bit input: Write enable vector
//                                        // for port B input data port dinb. 1 bit wide when word-wide writes are
//                                        // used. In byte-wide write configurations, each bit controls the
//                                        // writing one byte of dinb to address addrb. For example, to
//                                        // synchronously write only bits [15-8] of dinb when WRITE_DATA_WIDTH_B
//                                        // is 32, web would be 4'b0010.

//    );

wire[63:0] douta1_w;
wire[63:0] dinb1_w;

bytewrite_tdp_ram_rf vrf_1(
     .clkA(clk_r),
     .enaA(1'b1), 
     .weA(b_en_w),
     .addrA(Ac_w[9:0]),
     .dinA(Dc_w),
     .doutA(douta1_w),

     .clkB(clk_r),
     .enaB(1'b1),
     .weB(0),
     .addrB(addr_rd_A_VRF[9:0]),
     .dinB(dinb1_w),
     .doutB(Da_w)
);

wire[63:0] douta2_w;
wire[63:0] dinb2_w;

bytewrite_tdp_ram_rf vrf_2(
     .clkA(clk_r),
     .enaA(1'b1), 
     .weA(b_en_w),
     .addrA(Ac_w[9:0]),
     .dinA(Dc_w),
     .doutA(douta2_w),

     .clkB(clk_r),
     .enaB(1'b1),
     .weB(0),
     .addrB(addr_out_B_w[9:0]),
     .dinB(dinb2_w),
     .doutB(Da_w)
);

// wire dbiterra1_w;
// wire sbiterra1_w;

// wire dbiterrb1_w;
// wire sbiterrb1_w;

// wire[63:0] douta1_w;
// wire[63:0] dinb1_w;

//    xpm_memory_tdpram #(
//       .ADDR_WIDTH_A(10),               // DECIMAL
//       .ADDR_WIDTH_B(10),               // DECIMAL
//       .AUTO_SLEEP_TIME(0),            // DECIMAL
//       .BYTE_WRITE_WIDTH_A(8),        // DECIMAL
//       .BYTE_WRITE_WIDTH_B(8),        // DECIMAL
//       .CASCADE_HEIGHT(0),             // DECIMAL
//       .CLOCKING_MODE("common_clock"), // String
//       .ECC_MODE("no_ecc"),            // String
//       .MEMORY_INIT_FILE("none"),      // String
//       .MEMORY_INIT_PARAM("0"),        // String
//       .MEMORY_OPTIMIZATION("true"),   // String
//       .MEMORY_PRIMITIVE("auto"),      // String
//       .MEMORY_SIZE(65536),             // DECIMAL
//       .MESSAGE_CONTROL(0),            // DECIMAL
//       .READ_DATA_WIDTH_A(64),         // DECIMAL
//       .READ_DATA_WIDTH_B(64),         // DECIMAL
//       .READ_LATENCY_A(1),             // DECIMAL
//       .READ_LATENCY_B(1),             // DECIMAL
//       .READ_RESET_VALUE_A("0"),       // String
//       .READ_RESET_VALUE_B("0"),       // String
//       .RST_MODE_A("SYNC"),            // String
//       .RST_MODE_B("SYNC"),            // String
//       .SIM_ASSERT_CHK(0),             // DECIMAL; 0=disable simulation messages, 1=enable simulation messages
//       .USE_EMBEDDED_CONSTRAINT(0),    // DECIMAL
//       .USE_MEM_INIT(1),               // DECIMAL
//       .USE_MEM_INIT_MMI(0),           // DECIMAL
//       .WAKEUP_TIME("disable_sleep"),  // String
//       .WRITE_DATA_WIDTH_A(64),        // DECIMAL
//       .WRITE_DATA_WIDTH_B(64),        // DECIMAL
//       .WRITE_MODE_A("read_first"),     // String
//       .WRITE_MODE_B("read_first"),     // String
//       .WRITE_PROTECT(1)               // DECIMAL
//    )
//    xpm_memory_tdpram_inst1 (
//       .dbiterra(dbiterra1_w),             // 1-bit output: Status signal to indicate double bit error occurrence
//                                        // on the data output of port A.

//       .dbiterrb(dbiterrb1_w),             // 1-bit output: Status signal to indicate double bit error occurrence
//                                        // on the data output of port A.

//       .douta(douta1_w),                   // READ_DATA_WIDTH_A-bit output: Data output for port A read operations.
//       .doutb(Da_w),                   // READ_DATA_WIDTH_B-bit output: Data output for port B read operations.
//       .sbiterra(sbiterra1_w),             // 1-bit output: Status signal to indicate single bit error occurrence
//                                        // on the data output of port A.

//       .sbiterrb(sbiterrb1_w),             // 1-bit output: Status signal to indicate single bit error occurrence
//                                        // on the data output of port B.

//       .addra(Ac_w[9:0]),                   // ADDR_WIDTH_A-bit input: Address for port A write and read operations.
//       .addrb(addr_rd_A_VRF[9:0]),                   // ADDR_WIDTH_B-bit input: Address for port B write and read operations.
//       .clka(clk_r),                     // 1-bit input: Clock signal for port A. Also clocks port B when
//                                        // parameter CLOCKING_MODE is "common_clock".

//       .clkb(clk_r),                     // 1-bit input: Clock signal for port B when parameter CLOCKING_MODE is
//                                        // "independent_clock". Unused when parameter CLOCKING_MODE is
//                                        // "common_clock".

//       .dina(Dc_w),                     // WRITE_DATA_WIDTH_A-bit input: Data input for port A write operations.
//       .dinb(dinb1_w),                     // WRITE_DATA_WIDTH_B-bit input: Data input for port B write operations.
//       .ena(1'b1),                       // 1-bit input: Memory enable signal for port A. Must be high on clock
//                                        // cycles when read or write operations are initiated. Pipelined
//                                        // internally.

//       .enb(1'b1),                       // 1-bit input: Memory enable signal for port B. Must be high on clock
//                                        // cycles when read or write operations are initiated. Pipelined
//                                        // internally.

//       .injectdbiterra(1'b0), // 1-bit input: Controls double bit error injection on input data when
//                                        // ECC enabled (Error injection capability is not available in
//                                        // "decode_only" mode).

//       .injectdbiterrb(1'b0), // 1-bit input: Controls double bit error injection on input data when
//                                        // ECC enabled (Error injection capability is not available in
//                                        // "decode_only" mode).

//       .injectsbiterra(1'b0), // 1-bit input: Controls single bit error injection on input data when
//                                        // ECC enabled (Error injection capability is not available in
//                                        // "decode_only" mode).

//       .injectsbiterrb(1'b0), // 1-bit input: Controls single bit error injection on input data when
//                                        // ECC enabled (Error injection capability is not available in
//                                        // "decode_only" mode).

//       .regcea(1'b1),                 // 1-bit input: Clock Enable for the last register stage on the output
//                                        // data path.

//       .regceb(1'b1),                 // 1-bit input: Clock Enable for the last register stage on the output
//                                        // data path.

//       .rsta(rst_r),                     // 1-bit input: Reset signal for the final port A output register stage.
//                                        // Synchronously resets output port douta to the value specified by
//                                        // parameter READ_RESET_VALUE_A.

//       .rstb(rst_r),                     // 1-bit input: Reset signal for the final port B output register stage.
//                                        // Synchronously resets output port doutb to the value specified by
//                                        // parameter READ_RESET_VALUE_B.

//       .sleep(1'b0),                   // 1-bit input: sleep signal to enable the dynamic power saving feature.
//       .wea(b_en_w),                       // WRITE_DATA_WIDTH_A/BYTE_WRITE_WIDTH_A-bit input: Write enable vector
//                                        // for port A input data port dina. 1 bit wide when word-wide writes are
//                                        // used. In byte-wide write configurations, each bit controls the
//                                        // writing one byte of dina to address addra. For example, to
//                                        // synchronously write only bits [15-8] of dina when WRITE_DATA_WIDTH_A
//                                        // is 32, wea would be 4'b0010.

//       .web(0)                        // WRITE_DATA_WIDTH_B/BYTE_WRITE_WIDTH_B-bit input: Write enable vector
//                                        // for port B input data port dinb. 1 bit wide when word-wide writes are
//                                        // used. In byte-wide write configurations, each bit controls the
//                                        // writing one byte of dinb to address addrb. For example, to
//                                        // synchronously write only bits [15-8] of dinb when WRITE_DATA_WIDTH_B
//                                        // is 32, web would be 4'b0010.

//    );

// wire dbiterra2_w;
// wire sbiterra2_w;

// wire dbiterrb2_w;
// wire sbiterrb2_w;

// wire[63:0] douta2_w;
// wire[63:0] dinb2_w;

//    xpm_memory_tdpram #(
//       .ADDR_WIDTH_A(10),               // DECIMAL
//       .ADDR_WIDTH_B(10),               // DECIMAL
//       .AUTO_SLEEP_TIME(0),            // DECIMAL
//       .BYTE_WRITE_WIDTH_A(8),        // DECIMAL
//       .BYTE_WRITE_WIDTH_B(8),        // DECIMAL
//       .CASCADE_HEIGHT(0),             // DECIMAL
//       .CLOCKING_MODE("common_clock"), // String
//       .ECC_MODE("no_ecc"),            // String
//       .MEMORY_INIT_FILE("none"),      // String
//       .MEMORY_INIT_PARAM("0"),        // String
//       .MEMORY_OPTIMIZATION("true"),   // String
//       .MEMORY_PRIMITIVE("auto"),      // String
//       .MEMORY_SIZE(65536),             // DECIMAL
//       .MESSAGE_CONTROL(0),            // DECIMAL
//       .READ_DATA_WIDTH_A(64),         // DECIMAL
//       .READ_DATA_WIDTH_B(64),         // DECIMAL
//       .READ_LATENCY_A(1),             // DECIMAL
//       .READ_LATENCY_B(1),             // DECIMAL
//       .READ_RESET_VALUE_A("0"),       // String
//       .READ_RESET_VALUE_B("0"),       // String
//       .RST_MODE_A("SYNC"),            // String
//       .RST_MODE_B("SYNC"),            // String
//       .SIM_ASSERT_CHK(0),             // DECIMAL; 0=disable simulation messages, 1=enable simulation messages
//       .USE_EMBEDDED_CONSTRAINT(0),    // DECIMAL
//       .USE_MEM_INIT(1),               // DECIMAL
//       .USE_MEM_INIT_MMI(0),           // DECIMAL
//       .WAKEUP_TIME("disable_sleep"),  // String
//       .WRITE_DATA_WIDTH_A(64),        // DECIMAL
//       .WRITE_DATA_WIDTH_B(64),        // DECIMAL
//       .WRITE_MODE_A("read_first"),     // String
//       .WRITE_MODE_B("read_first"),     // String
//       .WRITE_PROTECT(1)               // DECIMAL
//    )
//    xpm_memory_tdpram_inst2 (
//       .dbiterra(dbiterra2_w),             // 1-bit output: Status signal to indicate double bit error occurrence
//                                        // on the data output of port A.

//       .dbiterrb(dbiterrb2_w),             // 1-bit output: Status signal to indicate double bit error occurrence
//                                        // on the data output of port A.

//       .douta(douta2_w),                   // READ_DATA_WIDTH_A-bit output: Data output for port A read operations.
//       .doutb(dout_mem_2),                   // READ_DATA_WIDTH_B-bit output: Data output for port B read operations.
//       .sbiterra(sbiterra2_w),             // 1-bit output: Status signal to indicate single bit error occurrence
//                                        // on the data output of port A.

//       .sbiterrb(sbiterrb2_w),             // 1-bit output: Status signal to indicate single bit error occurrence
//                                        // on the data output of port B.

//       .addra(Ac_w[9:0]),                   // ADDR_WIDTH_A-bit input: Address for port A write and read operations.
//       .addrb(addr_out_B_w[9:0]),                   // ADDR_WIDTH_B-bit input: Address for port B write and read operations.
//       .clka(clk_r),                     // 1-bit input: Clock signal for port A. Also clocks port B when
//                                        // parameter CLOCKING_MODE is "common_clock".

//       .clkb(clk_r),                     // 1-bit input: Clock signal for port B when parameter CLOCKING_MODE is
//                                        // "independent_clock". Unused when parameter CLOCKING_MODE is
//                                        // "common_clock".

//       .dina(Dc_w),                     // WRITE_DATA_WIDTH_A-bit input: Data input for port A write operations.
//       .dinb(dinb2_w),                     // WRITE_DATA_WIDTH_B-bit input: Data input for port B write operations.
//       .ena(1'b1),                       // 1-bit input: Memory enable signal for port A. Must be high on clock
//                                        // cycles when read or write operations are initiated. Pipelined
//                                        // internally.

//       .enb(1'b1),                       // 1-bit input: Memory enable signal for port B. Must be high on clock
//                                        // cycles when read or write operations are initiated. Pipelined
//                                        // internally.

//       .injectdbiterra(1'b0), // 1-bit input: Controls double bit error injection on input data when
//                                        // ECC enabled (Error injection capability is not available in
//                                        // "decode_only" mode).

//       .injectdbiterrb(1'b0), // 1-bit input: Controls double bit error injection on input data when
//                                        // ECC enabled (Error injection capability is not available in
//                                        // "decode_only" mode).

//       .injectsbiterra(1'b0), // 1-bit input: Controls single bit error injection on input data when
//                                        // ECC enabled (Error injection capability is not available in
//                                        // "decode_only" mode).

//       .injectsbiterrb(1'b0), // 1-bit input: Controls single bit error injection on input data when
//                                        // ECC enabled (Error injection capability is not available in
//                                        // "decode_only" mode).

//       .regcea(1'b1),                 // 1-bit input: Clock Enable for the last register stage on the output
//                                        // data path.

//       .regceb(1'b1),                 // 1-bit input: Clock Enable for the last register stage on the output
//                                        // data path.

//       .rsta(rst_r),                     // 1-bit input: Reset signal for the final port A output register stage.
//                                        // Synchronously resets output port douta to the value specified by
//                                        // parameter READ_RESET_VALUE_A.

//       .rstb(rst_r),                     // 1-bit input: Reset signal for the final port B output register stage.
//                                        // Synchronously resets output port doutb to the value specified by
//                                        // parameter READ_RESET_VALUE_B.

//       .sleep(1'b0),                   // 1-bit input: sleep signal to enable the dynamic power saving feature.
//       .wea(b_en_w),                       // WRITE_DATA_WIDTH_A/BYTE_WRITE_WIDTH_A-bit input: Write enable vector
//                                        // for port A input data port dina. 1 bit wide when word-wide writes are
//                                        // used. In byte-wide write configurations, each bit controls the
//                                        // writing one byte of dina to address addra. For example, to
//                                        // synchronously write only bits [15-8] of dina when WRITE_DATA_WIDTH_A
//                                        // is 32, wea would be 4'b0010.

//       .web(0)                        // WRITE_DATA_WIDTH_B/BYTE_WRITE_WIDTH_B-bit input: Write enable vector
//                                        // for port B input data port dinb. 1 bit wide when word-wide writes are
//                                        // used. In byte-wide write configurations, each bit controls the
//                                        // writing one byte of dinb to address addrb. For example, to
//                                        // synchronously write only bits [15-8] of dinb when WRITE_DATA_WIDTH_B
//                                        // is 32, web would be 4'b0010.

//    );
   
 vALU  #(
    .REQ_FUNC_ID_WIDTH(6 ),
    .REQ_DATA_WIDTH   (64),
    .RESP_DATA_WIDTH  (64),
    .SEW_WIDTH        (2 ),
    .REQ_ADDR_WIDTH   (32),
    .REQ_VL_WIDTH     (8 ),
    .REQ_BYTE_EN_WIDTH(8 ),
    .MIN_MAX_ENABLE   (1 ),
    .AND_OR_XOR_ENABLE(1 ),
    .ADD_SUB_ENABLE   (1 ),
    .SHIFT_ENABLE     (1 ),
    .MULT_ENABLE      (1 ),
    .MULT64_ENABLE    (1 ),
    .SLIDE_ENABLE     (1 ), 
    .WIDEN_ENABLE     (1 ),
    .NARROW_ENABLE    (1 ), 
    .MASK_ENABLE      (1 ),
    .REDUCTION_ENABLE (1 ),
    .VEC_MOVE_ENABLE  (1 )
) alu_ins (
    .clk(clk_r)         ,
    .rst(rst_r)         ,
    .req_valid(req_vld_dec_alu_c)   ,
    .req_func_id(opcode_w) ,
    .req_sew(vsew_w)     ,
    .req_data0(Da_w)   ,
    .req_data1(Db_w)   ,
    .req_addr(addr_out_C_w)    ,
    .req_be(b_en_agu_C_w)      ,
    .req_vl(vl_out_w)      ,
    .req_start(start_v_w),
    .req_end(end_v_w),

    .req_vl_out(req_vl_out_w)  , 

    .resp_data(dOut_alu)   ,
    .req_ready(req_rdy_alu)   , 
    .resp_valid(resp_valid_alu_w)  ,
    .req_addr_out(Addr_alu_vrf), 
    .req_be_out(req_be_out_alu_w)
);

custom_insns c_ins
(
    .clk(clk_r),
    .rst(rst_r),
    .c_in1(Da_w),
    .c_in2(Db_w),
    .req_vld(req_vld_dec_alu_c),
    .req_addr(addr_out_C_w),
    .req_be(b_en_agu_C_w),

    .rsp_res(dOut_cins),
    .req_rdy(req_rdy_c_agus),
    .rsp_vld(rsp_vld_c_reg),
    .rsp_addr(addr_out_cins),
    .rsp_be(b_en_out_c),
    .word_dword(w_dw_sel)
);


//vALU alu_ins(
//	.clk(clk_r)         ,
//	.rst(rst_r)         ,
//	.req_valid(req_vld_dec_alu_c)   ,
//	.req_func_id(opcode_w) ,
//	.req_sew(vsew_w)     ,
//	.req_data0(Da_w)   ,
//	.req_data1(Db_w)   ,
//	.req_addr(addr_out_C_w)    ,
//	.req_be(b_en_agu_C_w)      ,
//	.req_vl(vl_out_w)      ,
//	.resp_valid(resp_valid_alu_c_w)  ,
//	.resp_data(Dout_Alu_C)   ,
//	.req_ready(req_rdy_alu_c)   , //TODO:
//	.req_addr_out(Addr_alu_c_vrf), //TODO: pipeline
//	.req_vl_out(req_vl_out_w),    //TODO:pipeline
//	.req_be_out(req_be_out_alu_c_w)
//);

endmodule