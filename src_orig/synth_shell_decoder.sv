module synth_shell_decoder(
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

wire [31:0] Ac_w;

wire [63:0] Da_w;
wire [63:0] Db_w;
wire [63:0] Dc_w;
wire [63:0] Dc_Alu;
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
//--------------------------------

//Main memory --------------------

wire[31:0] addr_vld_vrf_w;

wire req_rdy_vld_w;
wire req_wr_vld_mm;
wire req_wr_vld_vrf;
//--------------------------------

//ALU-----------------------------
wire [31:0] Ac_alu_vrf_w;
//--------------------------------

//VLD-----------------------------
wire resp_ready_vld_w;
wire resp_valid_vld_w;
wire resp_ready_dec_vld_w;
//--------------------------------

//ALU-----------------------
wire [7:0] req_vl_out_w;
wire [7:0] req_be_out_w;
wire resp_valid_alu_w;

wire req_valid_alu;

wire req_ready_alu_w;

assign req_valid_alu = resp_valid_A_w & resp_valid_B_w & resp_valid_C_w;
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

wire req_wr_vld_w;

assign req_wr_vld_vrf = (sel_vld_res_w == 1) ? req_wr_vld_w : resp_valid_alu_w;

assign Dc_w = (sel_vld_res_w == 1) ? mm_data_out_w:Dc_Alu;
assign Ac_w = (sel_vld_res_w == 1) ? addr_vld_vrf_w:Ac_alu_vrf_w;

assign req_ready_AB_dec_w = req_ready_AGU_A_CTRL_w & req_ready_AGU_B_CTRL_w;

assign resp_valid_AB = resp_valid_B_w & resp_valid_A_w;

AGU agu_A (

    .clk(clk_r),
    .rst(rst_r),

    .VL_IN(vl_out_w),
    .VR_IN(vs1_w),
    .addr_out(addr_out_A_w),
    
    .req_valid(req_valid_dec_AB_w),
    .req_ready(req_ready_AGU_A_CTRL_w),

    //.resp_ready(req_ready_C_w),
    .resp_ready(resp_ready_dec_AB_w),
    .resp_valid(resp_valid_A_w)
);

AGU agu_B (

    .clk(clk_r),
    .rst(rst_r),

    .VL_IN(vl_out_w),
    .VR_IN(vs2_w),
    .addr_out(addr_out_B_w),
    
    .req_valid(req_valid_dec_AB_w),
    .req_ready(req_ready_AGU_B_CTRL_w),

    //.resp_ready(req_ready_C_w),
    .resp_ready(resp_ready_dec_AB_w),
    .resp_valid(resp_valid_B_w)
);

AGU agu_C (

    .clk(clk_r),
    .rst(rst_r),

    .VL_IN(vl_out_w),
    .VR_IN(vd_w),
    .addr_out(addr_out_C_w),
    
    .req_valid(req_valid_dec_C_w),
    .req_ready(req_ready_C_dec_w),

    .resp_ready(req_ready_alu_w),
    .resp_valid(resp_valid_C_w)
);

vld_unit vld_ins(
    .clk(clk_r),
    .rst(rst_r),

    .ADDR_IN(vld_addr_w),
    .N_DATA_IN(vl_out_w),
    .VR_IN(vd_w),
    
    .addr_out_mm(addr_vld_mm_w),
    .addr_out_vrf(addr_vld_vrf_w),

    .req_valid(req_valid_dec_vld_w),
    .req_ready(req_rdy_vld_w),
    .req_wr(req_wr_vld_w),

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

reg req_valid_dec_r = 0;

wire [2:0] vlmul_w;
wire [2:0] vsew_w;
wire vma_w;
wire [7:0] byte_en_w;

decoder DEC(
    .clk(clk_r),
    .rst(rst_r),

    //Input data
    .rs1(rs1_in),
    .rs2(32'd0),

    //Instruction in
    .insns(insns_r_w),

    .OPCODE(opcode_w),
    .VS1(vs1_w),
    .VS2(vs2_w),
    .VD(vd_w),
    .BASE_ADDR(vld_addr_w),

    //Output control signals and data
    .update_vl(update_vl_w),
    .vl_out(vl_out_w),

    .vlmul(vlmul_w),
    .vsew(vsew_w),
    .vma(vma_w),

    .byte_en(byte_en_w),

    //Address generators
    //ALU Data in selector
    
    /* Selects between vector load 
     * or the ALU result as input 
     * to the vector register file
     */
    
    .SEL_VLD_RES(sel_vld_res_w),

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
    .resp_ready_dec_C(resp_ready_dec_C_w)   
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

wire dbiterrb1_w;
wire sbiterrb_w;

xpm_memory_sdpram #(
      .ADDR_WIDTH_A(6),               // DECIMAL
      .ADDR_WIDTH_B(6),               // DECIMAL
      .AUTO_SLEEP_TIME(0),            // DECIMAL
      .BYTE_WRITE_WIDTH_A(64),        // DECIMAL
      .CASCADE_HEIGHT(0),             // DECIMAL
      .CLOCKING_MODE("common_clock"), // String
      .ECC_MODE("no_ecc"),            // String
      .MEMORY_INIT_FILE("none"),      // String
      .MEMORY_INIT_PARAM("0"),        // String
      .MEMORY_OPTIMIZATION("true"),   // String
      .MEMORY_PRIMITIVE("ultra"),      // String
      .MEMORY_SIZE(2048),             // DECIMAL
      .MESSAGE_CONTROL(0),            // DECIMAL
      .READ_DATA_WIDTH_B(64),         // DECIMAL
      .READ_LATENCY_B(1),             // DECIMAL
      .READ_RESET_VALUE_B("0"),       // String
      .RST_MODE_A("SYNC"),            // String
      .RST_MODE_B("SYNC"),            // String
      .SIM_ASSERT_CHK(0),             // DECIMAL; 0=disable simulation messages, 1=enable simulation messages
      .USE_EMBEDDED_CONSTRAINT(0),    // DECIMAL
      .USE_MEM_INIT(1),               // DECIMAL
      .USE_MEM_INIT_MMI(0),           // DECIMAL
      .WAKEUP_TIME("disable_sleep"),  // String
      .WRITE_DATA_WIDTH_A(64),        // DECIMAL
      .WRITE_MODE_B("read_first"),     // String
      .WRITE_PROTECT(1)               // DECIMAL
   )
   xpm_memory_sdpram_inst1 (
      .dbiterrb(dbiterrb1_w),             // 1-bit output: Status signal to indicate double bit error occurrence
                                       // on the data output of port B.

      .doutb(Da_w),                   // READ_DATA_WIDTH_B-bit output: Data output for port B read operations.
      .sbiterrb(sbiterrb_w),             // 1-bit output: Status signal to indicate single bit error occurrence
                                       // on the data output of port B.

      .addra(Ac_w[5:0]),                   // ADDR_WIDTH_A-bit input: Address for port A write operations.
      .addrb(addr_rd_A_VRF[5:0]),                   // ADDR_WIDTH_B-bit input: Address for port B read operations.
      .clka(clk_r),                     // 1-bit input: Clock signal for port A. Also clocks port B when
                                       // parameter CLOCKING_MODE is "common_clock".

      .clkb(clk_r),                     // 1-bit input: Clock signal for port B when parameter CLOCKING_MODE is
                                       // "independent_clock". Unused when parameter CLOCKING_MODE is
                                       // "common_clock".

      .dina(Dc_w),                     // WRITE_DATA_WIDTH_A-bit input: Data input for port A write operations.
      .ena(1'b1),                       // 1-bit input: Memory enable signal for port A. Must be high on clock
                                       // cycles when write operations are initiated. Pipelined internally.

      .enb(1'b1),                       // 1-bit input: Memory enable signal for port B. Must be high on clock
                                       // cycles when read operations are initiated. Pipelined internally.

      .injectdbiterra(1'b0), // 1-bit input: Controls double bit error injection on input data when
                                       // ECC enabled (Error injection capability is not available in
                                       // "decode_only" mode).

      .injectsbiterra(1'b0), // 1-bit input: Controls single bit error injection on input data when
                                       // ECC enabled (Error injection capability is not available in
                                       // "decode_only" mode).

      .regceb(1'b1),                 // 1-bit input: Clock Enable for the last register stage on the output
                                       // data path.

      .rstb(rst_r),                     // 1-bit input: Reset signal for the final port B output register stage.
                                       // Synchronously resets output port doutb to the value specified by
                                       // parameter READ_RESET_VALUE_B.

      .sleep(1'b0),                   // 1-bit input: sleep signal to enable the dynamic power saving feature.
      .wea(1)                        // WRITE_DATA_WIDTH_A/BYTE_WRITE_WIDTH_A-bit input: Write enable vector
                                       // for port A input data port dina. 1 bit wide when word-wide writes are
                                       // used. In byte-wide write configurations, each bit controls the
                                       // writing one byte of dina to address addra. For example, to
                                       // synchronously write only bits [15-8] of dina when WRITE_DATA_WIDTH_A
                                       // is 32, wea would be 4'b0010.

   );
   
wire dbiterrb2_w;
wire sbiterrb2_w;
   
xpm_memory_sdpram #(
      .ADDR_WIDTH_A(6),               // DECIMAL
      .ADDR_WIDTH_B(6),               // DECIMAL
      .AUTO_SLEEP_TIME(0),            // DECIMAL
      .BYTE_WRITE_WIDTH_A(64),        // DECIMAL
      .CASCADE_HEIGHT(0),             // DECIMAL
      .CLOCKING_MODE("common_clock"), // String
      .ECC_MODE("no_ecc"),            // String
      .MEMORY_INIT_FILE("none"),      // String
      .MEMORY_INIT_PARAM("0"),        // String
      .MEMORY_OPTIMIZATION("true"),   // String
      .MEMORY_PRIMITIVE("ultra"),      // String
      .MEMORY_SIZE(2048),             // DECIMAL
      .MESSAGE_CONTROL(0),            // DECIMAL
      .READ_DATA_WIDTH_B(64),         // DECIMAL
      .READ_LATENCY_B(1),             // DECIMAL
      .READ_RESET_VALUE_B("0"),       // String
      .RST_MODE_A("SYNC"),            // String
      .RST_MODE_B("SYNC"),            // String
      .SIM_ASSERT_CHK(0),             // DECIMAL; 0=disable simulation messages, 1=enable simulation messages
      .USE_EMBEDDED_CONSTRAINT(0),    // DECIMAL
      .USE_MEM_INIT(1),               // DECIMAL
      .USE_MEM_INIT_MMI(0),           // DECIMAL
      .WAKEUP_TIME("disable_sleep"),  // String
      .WRITE_DATA_WIDTH_A(64),        // DECIMAL
      .WRITE_MODE_B("read_first"),     // String
      .WRITE_PROTECT(1)               // DECIMAL
   )
   xpm_memory_sdpram_inst2 (
      .dbiterrb(dbiterrb2_w),             // 1-bit output: Status signal to indicate double bit error occurrence
                                       // on the data output of port B.

      .doutb(Db_w),                   // READ_DATA_WIDTH_B-bit output: Data output for port B read operations.
      .sbiterrb(sbiterrb2_w),             // 1-bit output: Status signal to indicate single bit error occurrence
                                       // on the data output of port B.

      .addra(Ac_w[5:0]),                   // ADDR_WIDTH_A-bit input: Address for port A write operations.
      .addrb(addr_out_B_w[5:0]),                   // ADDR_WIDTH_B-bit input: Address for port B read operations.
      .clka(clk_r),                     // 1-bit input: Clock signal for port A. Also clocks port B when
                                       // parameter CLOCKING_MODE is "common_clock".

      .clkb(clk_r),                     // 1-bit input: Clock signal for port B when parameter CLOCKING_MODE is
                                       // "independent_clock". Unused when parameter CLOCKING_MODE is
                                       // "common_clock".

      .dina(Dc_w),                     // WRITE_DATA_WIDTH_A-bit input: Data input for port A write operations.
      .ena(1'b1),                       // 1-bit input: Memory enable signal for port A. Must be high on clock
                                       // cycles when write operations are initiated. Pipelined internally.

      .enb(1'b1),                       // 1-bit input: Memory enable signal for port B. Must be high on clock
                                       // cycles when read operations are initiated. Pipelined internally.

      .injectdbiterra(1'b0), // 1-bit input: Controls double bit error injection on input data when
                                       // ECC enabled (Error injection capability is not available in
                                       // "decode_only" mode).

      .injectsbiterra(1'b0), // 1-bit input: Controls single bit error injection on input data when
                                       // ECC enabled (Error injection capability is not available in
                                       // "decode_only" mode).

      .regceb(1'b1),                 // 1-bit input: Clock Enable for the last register stage on the output
                                       // data path.

      .rstb(rst_r),                     // 1-bit input: Reset signal for the final port B output register stage.
                                       // Synchronously resets output port doutb to the value specified by
                                       // parameter READ_RESET_VALUE_B.

      .sleep(1'b0),                   // 1-bit input: sleep signal to enable the dynamic power saving feature.
      .wea(1)                        // WRITE_DATA_WIDTH_A/BYTE_WRITE_WIDTH_A-bit input: Write enable vector
                                       // for port A input data port dina. 1 bit wide when word-wide writes are
                                       // used. In byte-wide write configurations, each bit controls the
                                       // writing one byte of dina to address addra. For example, to
                                       // synchronously write only bits [15-8] of dina when WRITE_DATA_WIDTH_A
                                       // is 32, wea would be 4'b0010.

   );

vALU alu_ins(
	.clk(clk_r)         ,
	.rst(rst_r)         ,
	.req_valid(req_valid_alu)   ,
	.req_func_id(opcode_w) ,
	.req_sew(vsew_w)     ,
	.req_data0(Da_w)   ,
	.req_data1(Db_w)   ,
	.req_addr(addr_out_C_w)    ,
	.req_be(8'hFF)      ,
	.req_vl(vl_out_w)      ,
	.resp_valid(resp_valid_alu_w)  ,
	.resp_data(Dc_Alu)   ,
	.req_ready(req_ready_alu_w)   , //TODO:
	.req_addr_out(Ac_alu_vrf_w), //TODO: pipeline
	.req_vl_out(req_vl_out_w),    //TODO:pipeline
	.req_be_out(req_be_out_w)
);

endmodule