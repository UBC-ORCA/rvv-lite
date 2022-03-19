`include "vec_regfile.sv"
`include "insn_decoder.sv"
`include "addr_gen_unit.sv"
`include "vALU.v"

`define ALU_STG 5

// TODO: register groupings
// TODO:

module rvv_proc_main #(
    parameter VLEN = 64,        // vector length in bits
    parameter XLEN = 32,        // not sure, data width maybe?
    parameter NUM_VEC = 32,     // number of available vector registers
    parameter INSN_WIDTH = 32,  // width of a single instruction
    parameter DATA_WIDTH = 64,
    parameter DW_B = DATA_WIDTH/8,  // DATA_WIDTH in bytes
    parameter ADDR_WIDTH = 5,   //$clog2(NUM_VEC)
    parameter MEM_ADDR_WIDTH = 32,
    parameter REG_PORTS = 3
) (
    input clk,
    input rst,
    input [INSN_WIDTH-1:0] insn_in, // make this a queue I guess?
    input [DATA_WIDTH-1:0] mem_port_in,
    input [MEM_ADDR_WIDTH-1:0] mem_port_addr_in,
    output [DATA_WIDTH-1:0] mem_port_out,
    output [MEM_ADDR_WIDTH-1:0] mem_port_addr_out,
    output reg proc_rdy
);
    logic [DW_B-1:0] vr_en [REG_PORTS-1:0];
    logic vr_rw [REG_PORTS-1:0];
    logic [ADDR_WIDTH-1:0] vr_addr [REG_PORTS-1:0];
    logic [VLEN-1:0] vr_data_in [REG_PORTS-1:0];
    logic [VLEN-1:0] vr_data_out [REG_PORTS-1:0];
    logic [VLEN-1:0] vr_data_tmp [REG_PORTS-1:0];
  
    logic [INSN_WIDTH-1:0] insn_in_f;
  
    logic stall;
  
    // DEBUG
    logic [VLEN-1:0] vr_data_out_0;
    logic [VLEN-1:0] vr_data_out_1;
    logic [VLEN-1:0] vr_data_out_2;
    logic [VLEN-1:0] vr_data_in_0;
    logic [VLEN-1:0] vr_data_in_1;
    logic [VLEN-1:0] vr_data_in_2;
    logic [ADDR_WIDTH-1:0] vr_addr_0;
    logic [ADDR_WIDTH-1:0] vr_addr_1;
    logic [ADDR_WIDTH-1:0] vr_addr_2;

    // insn decomposition -- mostly general
    // realistically these shouldn't be registered but it makes it easier for now
    logic [6:0] opcode_mjr;
    logic [2:0] opcode_mnr;
    logic [4:0] dest;    // rd, vd, or vs3 -- TODO make better name lol
    logic [4:0] src_1;   // rs1, vs1, or imm/uimm
    logic [4:0] src_2;   // rs2, vs2, or imm -- for mem could be lumop, sumop

    // vmem
    logic [2:0] width;
    logic [1:0] mop;
    logic mew;
    logic [2:0] nf;

    // vcfg
    logic [10:0] vtype_11;
    logic [9:0]  vtype_10;
    logic [1:0]  cfg_type;

    // valu
    logic vm;
    logic [5:0] funct6;

    // value propagation signals
    logic [6:0] opcode_mjr_d;
    logic [2:0] opcode_mnr_d;
    logic [4:0] src_1_d;
    logic [4:0] src_2_d;
    logic [4:0] dest_d;    // rd, vd, or vs3 -- TODO make better name lol
    logic [5:0] funct6_d;

    logic [6:0] opcode_mjr_e  [`ALU_STG-1:0];
    logic [2:0] opcode_mnr_e  [`ALU_STG-1:0];
    logic [4:0] src_1_e     [`ALU_STG-1:0];
    logic [4:0] src_2_e     [`ALU_STG-1:0];
    logic [4:0] dest_e        [`ALU_STG-1:0];    // rd, vd, or vs3 -- TODO make better name lol
    logic [5:0] funct6_e      [`ALU_STG-1:0];

    logic [6:0] opcode_mjr_m;
    logic [2:0] opcode_mnr_m;
    logic [4:0] src_1_m;
    logic [4:0] src_2_m;
    logic [4:0] dest_m;    // rd, vd, or vs3 -- TODO make better name lol
    logic [5:0] funct6_m;

    logic [6:0] opcode_mjr_w;
    logic [2:0] opcode_mnr_w;
    logic [4:0] src_1_w;
    logic [4:0] src_2_w;
    logic [4:0] dest_w;    // rd, vd, or vs3 -- TODO make better name lol
    logic [5:0] funct6_w;

    // CONFIG VALUES
    logic [4:0] avl; // Application Vector Length (vlen effective)
  
    // VTYPE values
    logic [2:0]         sew;
    logic [2:0]         vlmul;
    logic [XLEN-1:0]    vtype;
    logic               vma;
    logic               vta;
    logic               vill;
  
    logic [XLEN-1:0]    vtype_nxt;
    logic [3:0]         reg_count;

    logic agu_idle [REG_PORTS-1:0];

    logic alu_enable;
    logic [2:0] alu_req_sew;
    logic [DATA_WIDTH-1:0] s_ext_imm;
    logic [DATA_WIDTH-1:0] s_ext_imm_d;
    logic [DATA_WIDTH-1:0] s_ext_imm_e;
    
//   wire alu_req_valid;
//   wire alu_req_be;
//   wire alu_req_vl;
//   wire alu_req_start;
//   wire alu_req_end;

    logic [DATA_WIDTH-1:0] alu_data_in1;
    logic [DATA_WIDTH-1:0] alu_data_in2;
    logic [DATA_WIDTH-1:0] alu_data_out;

    logic [ADDR_WIDTH-1:0] alu_req_addr_out;
    logic alu_valid_out;
  
    logic [2:0] opcode_mnr_e_0;
  
    logic hold_reg_group;
    logic raw_hazard;
  
    logic vec_has_hazard [0:NUM_VEC-1]; // use this to indicate that vec needs bubble????
  
    logic no_bubble;
    
    genvar i;

//   wire alu_resp_valid;
//   wire alu_req_ready;
//   wire alu_req_vl_out;
//   wire alu_req_be_out;

// -------------------------------------------------- CONNECTED MODULES ---------------------------------------------------------------------------------

  insn_decoder #(.INSN_WIDTH(INSN_WIDTH)) id (.clk(clk), .rst(rst), .insn_in(insn_in_f), .opcode_mjr(opcode_mjr), .opcode_mnr(opcode_mnr), .dest(dest), .src_1(src_1), .src_2(src_2),
        .width(width), .mop(mop), .mew(mew), .nf(nf), .vtype_11(vtype_11), .vtype_10(vtype_10), .vm(vm), .funct6(funct6), .cfg_type(cfg_type));

    // TODO: figure out how to make this single cycle, so we can fully pipeline lol
    addr_gen_unit #(.ADDR_WIDTH(ADDR_WIDTH)) agu_src1 (.clk(clk), .rst(rst), .en(en_vs1), .vlmul(vlmul), .addr_in(src_1), .addr_out(vr_addr[0]), .idle(agu_idle[0]));
    addr_gen_unit #(.ADDR_WIDTH(ADDR_WIDTH)) agu_src2 (.clk(clk), .rst(rst), .en(en_vs2), .vlmul(vlmul), .addr_in(src_2), .addr_out(vr_addr[1]), .idle(agu_idle[1]));
    addr_gen_unit #(.ADDR_WIDTH(ADDR_WIDTH)) agu_dest (.clk(clk), .rst(rst), .en(en_vd), .vlmul(vlmul), .addr_in(alu_req_addr_out), .addr_out(vr_addr[2]), .idle(agu_idle[2]));

    // TODO: add normal regfile? connect to external one? what do here
    vec_regfile #(.VLEN(VLEN), .DATA_WIDTH(DATA_WIDTH), .ADDR_WIDTH(ADDR_WIDTH), .PORTS(REG_PORTS)) vr (.clk(clk), .rst(rst), .en(vr_en), .rw(vr_rw), .addr(vr_addr), .data_in(vr_data_in), .data_out(vr_data_out));

    // ------------------------- BEGIN DEBUG --------------------------
    // Read vector sources
    // TODO: add mask read logic
    assign vr_data_out_0 = vr_data_out[0];
    assign vr_data_out_1 = vr_data_out[1];
    assign vr_data_out_2 = vr_data_out[2];

    assign vr_data_in_0 = vr_data_in[0];
    assign vr_data_in_1 = vr_data_in[1];
    assign vr_data_in_2 = vr_data_in[2];

    assign vr_en_0 = vr_en[0];
    assign vr_en_1 = vr_en[1];
    assign vr_en_2 = vr_en[2];

    assign vr_addr_0 = vr_addr[0];
    assign vr_addr_1 = vr_addr[1];
    assign vr_addr_2 = vr_addr[2];

    assign vr_rw_0 = vr_rw[0];
    assign vr_rw_2 = vr_rw[2];
  
    assign opcode_mnr_e_0 = opcode_mnr_e[0];
  
    assign haz_src1 = (vec_has_hazard[src_1] && en_vs1);
    assign haz_src2 = (vec_has_hazard[src_2] && en_vs2);
  
    assign haz_0 = vec_has_hazard[0];
    assign haz_1 = vec_has_hazard[1];
    assign haz_2 = vec_has_hazard[2];
    assign haz_3 = vec_has_hazard[3];
    assign haz_4 = vec_has_hazard[4];
    assign haz_5 = vec_has_hazard[5];
    assign haz_6 = vec_has_hazard[6];
    assign haz_7 = vec_has_hazard[7];

    // ------------------------- END DEBUG --------------------------
    
    // need to stall for register groupings
    // TODO: stall for hazards
    always @(posedge clk or negedge rst) begin   
      insn_in_f <= ((hold_reg_group & reg_count > 0) | haz_src1 | haz_src2) ? insn_in_f : insn_in;
//          if (~rst) begin
//          stall <= 1'b1;
//          end else begin
//              //raw_hazard <= 0;//(dest === 0);// || (vec_has_hazard[0] && dest_w !== 0);
        stall <= ~rst | (hold_reg_group & reg_count > 0) | haz_src1 | haz_src2;// | vec_has_hazard[src_1] | vec_has_hazard[src_2]; // TODO: update with hazards :)
//          end
    end
  
//   assign stall = ~rst | hold_reg_group | haz_src1 | haz_src2;
  
    generate
        for (i = 0; i < NUM_VEC; i++) begin
            always @(posedge clk or negedge rst) begin
                if (~rst) begin
                    vec_has_hazard[i] <= 0; // pipeline is reset, no hazards
                end else begin
                    // set high if incoming vector is going to overwrite the destination, or it has a hazard that isn't being cleared this cycle
                    // else, set low
                    vec_has_hazard[i] <= (((dest == i) & (opcode_mjr === 7'h57 && opcode_mnr < 7)) | (vec_has_hazard[i] & ~((alu_req_addr_out == i) & alu_valid_out))) ; // FIXME opcode check
                end
            end
        end
    endgenerate
  
    assign proc_rdy = ~stall;
  
    // -------------------------------------------------- CONTROL SIGNALS ---------------------------------------------------------------------------------

    // VLEN AND VSEW
    // TODO: breakout into cfg unit
    // TODO: store AVL value in register
  assign vtype_nxt = cfg_type[1] ? {12'h0, vtype_10} : {11'h0, vtype_11};
      
    always @(posedge clk or negedge rst) begin
        if (~rst) begin
            sew     <= 3'h0;
            vlmul   <= 3'h0;
            vma     <= 1'b0;
            vta     <= 1'b0;
            vill    <= 1'b0;
            avl     <= VLEN;
        end else begin
            // only change if there is an explicit cfg instruction, obviously
            if (opcode_mjr === 7'h57 && opcode_mnr === 3'h7) begin
              // update vtype values if using vset{i}vli
                if (cfg_type[1] === 1'b0 || cfg_type === 2'b11) begin
                    vlmul   <= vtype_nxt[2:0];
                    sew     <= vtype_nxt[5:3];
                    vma     <= vtype_nxt[6];
                    vta     <= vtype_nxt[7];
                    vill    <= vtype_nxt[XLEN-1];
                end
                // Update AVL directly if using vsetivli
              // TODO: register version, which is more reasonable tbh (5 bits is too small for a vector lol)
                if (cfg_type === 2'b11) begin
                    avl     <= src_1;
                end
            end
        end
    end

    // ---------------------------------------- ALU --------------------------------------------------------------------------------

    // TODO: hold values steady while waiting for multiple register groupings...
  
    // SIGN-EXTENDED IMMEDIATE FOR ALU
    assign hold_reg_group = rst & ((reg_count > 0) || (opcode_mjr === 7'h57 && opcode_mnr < 7 && vlmul > 0)); // hold if we are starting a reg group or currently processing one
    
    always_comb begin
        case (alu_req_sew)
            3'h0:     s_ext_imm = {{(DATA_WIDTH-8){1'b0}}, {3{src_1[4]}}, src_1};
            3'h1:     s_ext_imm = {{(DATA_WIDTH-16){1'b0}}, {11{src_1[4]}}, src_1};
            3'h2:     s_ext_imm = {{(DATA_WIDTH-32){1'b0}}, {27{src_1[4]}}, src_1};
            3'h3:     s_ext_imm = {{(DATA_WIDTH-64){1'b0}}, {59{src_1[4]}}, src_1};
            default:  s_ext_imm = 3'h0;
        endcase
    end
  
    always @(posedge clk) begin
        if (~rst) begin
            reg_count   <= 'h0;
            s_ext_imm_d <= 'h0;
            s_ext_imm_e <= 'h0;
        end else begin
            reg_count <= (reg_count > 0)    ? reg_count - 1 : (hold_reg_group ? ((1'b1 << vlmul) - 1) : 0);

            s_ext_imm_d <= (reg_count === 0) ? s_ext_imm : s_ext_imm_d; // latch value for register groupings

            // new simm when its an intermediate input and we aren't mid-instruction
            s_ext_imm_e <= s_ext_imm_d;
        end
    end

    // ALU INPUTS
  
    always @(posedge clk) begin
        // enable ALU if ALU op AND ((VR enabled AND valu.vv) OR valu.vi OR valu.vx)
      alu_enable  <= (((vr_en[0][0] || vr_en[1][0]) && (opcode_mnr_d == 3'b0)) || (opcode_mnr_d == 3'b011) || (opcode_mnr_d == 3'b100)) && (opcode_mjr_d === 7'h57);
        alu_req_sew <= sew;
    end

    // ASSIGNING FIRST SOURCE BASED ON OPCODE TYPE (VX vs VI vs VV)
    always_comb begin
        case (opcode_mnr_e[0])
            3'h0:   alu_data_in1 = vr_data_out[0];  // valu.vv
            3'h3: begin // valu.vi
                case (alu_req_sew)
                    2'b00:    alu_data_in1 = {DW_B{s_ext_imm_e[7:0]}};
                    2'b01:    alu_data_in1 = {(DW_B/2){s_ext_imm_e[15:0]}};
                    2'b10:    alu_data_in1 = {(DW_B/4){s_ext_imm_e[31:0]}};
                    2'b11:    alu_data_in1 = {(DW_B/8){s_ext_imm_e[63:0]}};
                    default:  alu_data_in1 = {s_ext_imm_e};
                endcase
            end
            default:  alu_data_in1 = 'hX;
        endcase
    end

    // source 2 is always source 2 for ALU
    assign alu_data_in2 = vr_data_out[0];

    // TODO: update to use active low reset lol
    vALU #(.REQ_DATA_WIDTH(DATA_WIDTH), .RESP_DATA_WIDTH(DATA_WIDTH), .REQ_ADDR_WIDTH(ADDR_WIDTH)) alu (.clk(clk), .rst(~rst),
        .req_valid(alu_enable), .req_func_id(funct6_e[0]), .req_sew(alu_req_sew[1:0]), .req_data0(alu_data_in1), .req_data1(alu_data_in2), .req_addr(dest_d),
        .resp_valid(alu_valid_out), .resp_data(alu_data_out), .req_addr_out(alu_req_addr_out));
    //  MISSING PORT CONNECTIONS:
    //     input      [REQ_BYTE_EN_WIDTH-1:0] req_be      ,
    //     input      [     REQ_VL_WIDTH-1:0] req_vl      ,
    //     input                              req_start   ,
    //     input                              req_end     ,
    //     output                             req_ready   ,
    //     output reg [     REQ_VL_WIDTH-1:0] req_vl_out  ,
    //     output reg [REQ_BYTE_EN_WIDTH-1:0] req_be_out
    // );
  
    // used only for OPIVV, OPFVV, OPMVV
    assign en_vs1 = no_bubble & (opcode_mjr === 7'h57 && opcode_mnr >= 3'h0 && opcode_mnr <= 3'h2);

    // used for all ALU and one each of load/store
    assign en_vs2 = no_bubble & (opcode_mjr === 7'h57 && opcode_mnr !== 3'h7 && funct6 !== 'h17) || (opcode_mjr === 7'h7 && mop[0]) || (opcode_mjr === 7'h27 && mop[0]);

    // used for LOAD-FP (m stage) and ALU (wb stage)
    assign en_vd = alu_valid_out;//(opcode_mjr_e === 7'h57 && opcode_mnr_e !== 3'h7); //(opcode_mjr_m == 7'h7) ||

    // lol bro thats not how store works
    // used only for STORE-FP in M stage
    assign en_vs3 = (opcode_mjr_m === 7'h27 && opcode_mnr_m >= 3'h0 && opcode_mnr_m <= 3'h2);


    assign vr_en[0] = {DW_B{~agu_idle[0]}};
    assign vr_en[1] = {DW_B{~agu_idle[1]}};   //rst & en_vs2;
    assign vr_rw[0] = agu_idle[0];
    assign vr_rw[1] = agu_idle[1];

    // TODO: memory lol
    // could just run load/store in parallel with ALU theoretically

    // --------------------------------------------------- WRITEBACK STAGE LOGIC --------------------------------------------------------------
    always_ff @(posedge clk or negedge rst) begin
        if (~rst) begin
            vr_data_in[2] <= 'h0;
        end else begin
            vr_data_in[2] <= (alu_valid_out === 1'b1) ? alu_data_out : 'hDEADBEEF;
        end
    end

    assign vr_rw[2] = ~agu_idle[2];
    assign vr_en[2] = {DW_B{~agu_idle[2]}}; // TODO: add byte masking


    // -------------------------------------------------- SIGNAL PROPAGATION LOGIC ------------------------------------------------------------
    assign no_bubble = hold_reg_group & ~(haz_src1 | haz_src2);
    always_ff @(posedge clk or negedge rst) begin
        if(~rst) begin
            opcode_mjr_d    <= 0;
            opcode_mnr_d    <= 0;
            dest_d          <= 0;
            funct6_d        <= 0;

//             opcode_mjr_e[0] <= 0;
//             opcode_mnr_e[0] <= 0;
//             dest_e[0]       <= 0;
//             funct6_e[0]     <= 0;

//             opcode_mjr_w    <= 0;
//             opcode_mnr_w    <= 0;
//             dest_w          <= 0;
//             funct6_w        <= 0;
        end else begin
            // all stalling should happen here
          opcode_mjr_d    <= (reg_count === 'h0) ? opcode_mjr : (no_bubble ? opcode_mjr_d : 'h0);
          opcode_mnr_d    <= (reg_count === 'h0) ? opcode_mnr : (no_bubble ? opcode_mnr_d : 'h0);
          dest_d          <= (reg_count === 'h0) ? dest : (no_bubble ? dest_d : 'h0);
          funct6_d        <= (reg_count === 'h0) ? funct6 : (no_bubble ? funct6_d : 'h0);

//              opcode_mjr_e[0] <= opcode_mjr_d;
//              opcode_mnr_e[0] <= opcode_mnr_d;
//              dest_e[0]       <= dest_d;
//              funct6_e[0]     <= funct6_d;

//             opcode_mjr_w    <= opcode_mjr_e[`ALU_STG-1];
//             opcode_mnr_w    <= opcode_mnr_e[`ALU_STG-1];
//             dest_w          <= dest_e[`ALU_STG-1];
//             funct6_w        <= funct6_e[`ALU_STG-1];
        end
    end

    // Separate ALU stage logic lol
//     generate
//         for (i = 1; i < `ALU_STG; i++) begin
//             always_ff @(posedge clk or negedge rst) begin
//                 if(~rst) begin
//                     opcode_mjr_e[i] <= 0;
//                     opcode_mnr_e[i] <= 0;
//                     dest_e[i]       <= 0;
//                     funct6_e[i]     <= 0;
//                 end else begin
//                     opcode_mjr_e[i] <= opcode_mjr_e[i-1];
//                     opcode_mnr_e[i] <= opcode_mnr_e[i-1];
//                     dest_e[i]       <= dest_e[i-1];
//                     funct6_e[i]     <= funct6_e[i-1];
//                 end
//             end
//         end
//     endgenerate

endmodule