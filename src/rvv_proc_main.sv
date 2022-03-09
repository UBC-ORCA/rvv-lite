`include "vec_regfile.sv"
`include "insn_decoder.sv"
`include "addr_gen_unit.sv"
`include "vALU.v"

// TODO: register groupings
// TODO: 

module rvv_proc_main
  #(parameter VLEN = 64,   // vector length in bits
    parameter NUM_VEC = 32,     // number of available vector registers
    parameter INSN_WIDTH = 32,   // width of a single instruction
    parameter DATA_WIDTH = 64,
    parameter DW_B = DATA_WIDTH/8,   // DATA_WIDTH in bytes
    parameter ADDR_WIDTH = 5,//$clog2(NUM_VEC),
    parameter REG_PORTS = 3
) (
    input clk,
    input rst,

    input [INSN_WIDTH-1:0] insn_in, // make this a queue I guess?

    output proc_idle
);
    reg [DW_B-1:0] vr_en [REG_PORTS-1:0];
    reg vr_rw [REG_PORTS-1:0];
    reg [ADDR_WIDTH-1:0] vr_addr [REG_PORTS-1:0];
    reg [VLEN-1:0] vr_data_in [REG_PORTS-1:0];
    reg [VLEN-1:0] vr_data_out [REG_PORTS-1:0];
    reg [VLEN-1:0] vr_data_tmp [REG_PORTS-1:0];

    wire [VLEN-1:0] vr_data_out_0;
    wire [VLEN-1:0] vr_data_out_1;
    wire [VLEN-1:0] vr_data_out_2;
    wire [VLEN-1:0] vr_data_in_0;
    wire [VLEN-1:0] vr_data_in_1;
    wire [VLEN-1:0] vr_data_in_2;
    wire [ADDR_WIDTH-1:0] vr_addr_0;
    wire [ADDR_WIDTH-1:0] vr_addr_1;
    wire [ADDR_WIDTH-1:0] vr_addr_2;
  
    // insn decomposition -- mostly general
    // realistically these shouldn't be registered but it makes it easier for now
    wire [6:0] opcode_mjr;
    wire [2:0] opcode_mnr;
    wire [4:0] dest;    // rd, vd, or vs3 -- TODO make better name lol
    wire [4:0] src_1;   // rs1, vs1, or imm/uimm
    wire [4:0] src_2;   // rs2, vs2, or imm -- for mem could be lumop, sumop

    reg [6:0] opcode_mjr_d;
    reg [2:0] opcode_mnr_d;
    reg [4:0] dest_d;    // rd, vd, or vs3 -- TODO make better name lol
    reg [5:0] funct6_d;     
  
    reg [6:0] opcode_mjr_e;
    reg [2:0] opcode_mnr_e;
    reg [4:0] dest_e;    // rd, vd, or vs3 -- TODO make better name lol
    reg [5:0] funct6_e;
  
    reg [6:0] opcode_mjr_m;
    reg [2:0] opcode_mnr_m;
    reg [4:0] dest_m;    // rd, vd, or vs3 -- TODO make better name lol
    reg [5:0] funct6_m;
  
    reg [6:0] opcode_mjr_w;
    reg [2:0] opcode_mnr_w;
    reg [4:0] dest_w;    // rd, vd, or vs3 -- TODO make better name lol
    reg [5:0] funct6_w;
  
    reg [2:0] sew;

    // vmem
    wire [2:0] width;
    wire [1:0] mop;
    wire mew;
    wire [2:0] nf;

    // vcfg
    wire [10:0] zimm_11;
    wire [9:0]  zimm_10;

    // valu
    wire vm;
    wire [5:0] funct6;
  
    wire [2:0] vlmul;
  
    wire agu_idle [REG_PORTS-1:0];
    
  reg alu_enable;
  //   wire alu_req_valid;
//   wire alu_req_sew;
//   wire alu_req_be;
//   wire alu_req_vl;
//   wire alu_req_start;
//   wire alu_req_end;
  
//   wire alu_resp_valid;
  wire [DATA_WIDTH-1:0] alu_data_out;
//   wire alu_req_ready;
  wire [ADDR_WIDTH-1:0] alu_req_addr_out;
  wire alu_valid_out;
//   wire alu_req_vl_out;
//   wire alu_req_be_out;

    insn_decoder #(.INSN_WIDTH(INSN_WIDTH)) id (.clk(clk), .rst(rst), .insn_in(insn_in), .opcode_mjr(opcode_mjr), .opcode_mnr(opcode_mnr), .dest(dest), .src_1(src_1), .src_2(src_2),
                                                .width(width), .mop(mop), .mew(mew), .nf(nf), .zimm_11(zimm_11), .zimm_10(zimm_10), .vm(vm), .funct6(funct6));

    // TODO: figure out how to make this single cycle, so we can fully pipeline lol
    addr_gen_unit #(.ADDR_WIDTH(ADDR_WIDTH)) agu_src1 (.clk(clk), .rst(rst), .en(en_vs1), .vlmul(vlmul), .addr_in(src_1), .addr_out(vr_addr[0]), .idle(agu_idle[0]));
    addr_gen_unit #(.ADDR_WIDTH(ADDR_WIDTH)) agu_src2 (.clk(clk), .rst(rst), .en(en_vs2), .vlmul(vlmul), .addr_in(src_2), .addr_out(vr_addr[1]), .idle(agu_idle[1]));
//     addr_gen_unit #(.ADDR_WIDTH(ADDR_WIDTH)) agu_dest (.clk(clk), .rst(rst), .en(en_vd), .vlmul(vlmul), .addr_in(dest_e), .addr_out(vr_addr[2]), .idle(agu_idle[2]));
  addr_gen_unit #(.ADDR_WIDTH(ADDR_WIDTH)) agu_dest (.clk(clk), .rst(rst), .en(en_vd), .vlmul(vlmul), .addr_in(alu_req_addr_out), .addr_out(vr_addr[2]), .idle(agu_idle[2]));
  
    // TODO: add normal regfile? connect to external one? what do here

    vec_regfile #(.VLEN(VLEN), .DATA_WIDTH(DATA_WIDTH), .ADDR_WIDTH(ADDR_WIDTH), .PORTS(REG_PORTS)) vr (.clk(clk), .rst(rst), .en(vr_en), .rw(vr_rw), .addr(vr_addr), .data_in(vr_data_in), .data_out(vr_data_out));
  
//   assign alu_enable = (vr_en[0][0] || vr_en[1][0]) && (opcode_mjr === 7'h57);
  always @(posedge clk) begin
    alu_enable <= (vr_en[0][0] || vr_en[1][0]) && (opcode_mjr_d === 7'h57);
  end
//     alu_enable <= (en_vs1 || en_vs2) && (opcode_mjr === 7'h57);
    
//     vr_data_in[2] <= alu_data_out;
//   end
  
  // TODO: update to use active low reset lol
  vALU #(.REQ_DATA_WIDTH(DATA_WIDTH), .RESP_DATA_WIDTH(DATA_WIDTH), .REQ_ADDR_WIDTH(ADDR_WIDTH)) alu (.clk(clk), .rst(~rst), .req_valid(alu_enable), .req_func_id(funct6_e), .req_data0(vr_data_out[0]), .req_data1(vr_data_out[1]), .req_addr(dest), .req_sew('h3), .resp_data(alu_data_out), .req_addr_out(alu_req_addr_out), .resp_valid(alu_valid_out));
//   (
//     input                              clk         ,
//     input                              rst         ,
//     input                              req_valid   ,
//     input      [REQ_FUNC_ID_WIDTH-1:0] req_func_id ,
//     input      [        SEW_WIDTH-1:0] req_sew     ,
//     input      [   REQ_DATA_WIDTH-1:0] req_data0   ,
//     input      [   REQ_DATA_WIDTH-1:0] req_data1   ,
//     input      [   REQ_ADDR_WIDTH-1:0] req_addr    ,
//     input      [REQ_BYTE_EN_WIDTH-1:0] req_be      ,
//     input      [     REQ_VL_WIDTH-1:0] req_vl      ,
//     input                              req_start   ,
//     input                              req_end     ,
//     output reg                         resp_valid  ,
//     output reg [  RESP_DATA_WIDTH-1:0] resp_data   ,
//     output                             req_ready   ,
//     output reg [   REQ_ADDR_WIDTH-1:0] req_addr_out,
//     output reg [     REQ_VL_WIDTH-1:0] req_vl_out  ,
//     output reg [REQ_BYTE_EN_WIDTH-1:0] req_be_out
// );
  
    assign vlmul = 3'b000;  // TODO: implement vtype

    // used only for OPIVV, OPFVV, OPMVV
  assign en_vs1 = (opcode_mjr === 7'h57 && opcode_mnr >= 3'h0 && opcode_mnr <= 3'h2);

    // used for all ALU and one each of load/store
  assign en_vs2 = (opcode_mjr === 7'h57 && opcode_mnr !== 3'h7 && funct6 !== 'h17) || (opcode_mjr === 7'h7 && mop[0]) || (opcode_mjr === 7'h27 && mop[0]);
  
    // used for LOAD-FP (m stage) and ALU (wb stage)
  assign en_vd = alu_valid_out;//(opcode_mjr_e === 7'h57 && opcode_mnr_e !== 3'h7); //(opcode_mjr_m == 7'h7) || 

    // lol bro thats not how store works
    // used only for STORE-FP in M stage
  assign en_vs3 = (opcode_mjr_m === 7'h27 && opcode_mnr_m >= 3'h0 && opcode_mnr_m <= 3'h2);

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
  
// ------------------------- END DEBUG --------------------------
  
  assign vr_en[0] = {DW_B{~agu_idle[0]}};
  assign vr_en[1] = {DW_B{~agu_idle[1]}};   //rst & en_vs2;
  assign vr_rw[0] = agu_idle[0];
  assign vr_rw[1] = agu_idle[1];

  assign proc_idle = (opcode_mjr === 'h0) && (opcode_mjr_e === 'h0) && (opcode_mjr_w === 'h0);
    
  // clock the writeback stage data i guess
//   always_ff @(posedge clk or negedge rst) begin
//     if(~rst) begin
//     end else begin
//       vr_data_in[2] <= (opcode_mjr_w == 7'h57 && funct6_w == 6'h17) ? vr_data_out[0] : 'hXXXXXX;
//     end
//   end
      
      
//   assign vr_data_in[2] = (opcode_mjr_w == 7'h57 && funct6_w == 6'h17) ? vr_data_out[0] : 'hDEADBEEF; // TODO: assign second option to ALU output or MEM output (depending on opcode)
//   assign vr_rw[2]   = ~agu_idle[2];//rst & en_vd;
//   assign vr_en[2]   = {DW_B{~agu_idle[2]}};//{DW_B{rst & en_vd}}; // TODO: add byte masking
  
  always_ff @(posedge clk or negedge rst) begin
    if (~rst) begin
        vr_data_in[2] <= 'h0;
    end else begin
      vr_data_in[2] <= (alu_valid_out === 1'b1) ? alu_data_out : 'hDEADBEEF;
    end
  end
//   assign vr_data_in[2] = alu_valid_out ? alu_data_out : 'hDEADBEEF; // TODO: assign second option to ALU output or MEM output (depending on opcode)
  assign vr_rw[2]   = ~agu_idle[2];//rst & en_vd;
  assign vr_en[2]   = {DW_B{~agu_idle[2]}};//{DW_B{rst & en_vd}}; // TODO: add byte masking
  
//   assign vr_en[2] = {DW_B{(rst & en_vd)}};

    // add cycle delay to destination regs
    always_ff @(posedge clk or negedge rst) begin
        if(~rst) begin
          // use these because the ALU makes timing weird
            opcode_mjr_d    <= 0;
            opcode_mnr_d    <= 0;
            dest_d          <= 0;
            funct6_d        <= 0;
          
            opcode_mjr_e    <= 0;
            opcode_mnr_e    <= 0;
            dest_e          <= 0;
            funct6_e        <= 0;

            opcode_mjr_m    <= 0;
            opcode_mnr_m    <= 0;
            dest_m          <= 0;
            funct6_m        <= 0;
          
            opcode_mjr_w    <= 0;
            opcode_mnr_w    <= 0;
            dest_w          <= 0;
            funct6_w        <= 0;
        end else begin
            opcode_mjr_d    <= opcode_mjr;
            opcode_mnr_d    <= opcode_mnr;
            dest_d          <= dest;
            funct6_d        <= funct6;
          
            opcode_mjr_e    <= opcode_mjr_d;
            opcode_mnr_e    <= opcode_mnr_d;
            dest_e          <= dest_d;
            funct6_e        <= funct6_d;

            opcode_mjr_m    <= opcode_mjr_d;
            opcode_mnr_m    <= opcode_mnr_d;
            dest_m          <= dest_d;
            funct6_m        <= funct6_d;
          
            opcode_mjr_w    <= opcode_mjr_e;
            opcode_mnr_w    <= opcode_mnr_e;
            dest_w          <= dest_e;
            funct6_w        <= funct6_e;
        end
    end

    // TODO: somehow signal that the vectors are ready lol
    // reg rdy_vs1
    // reg rdy_vs2

    // could just run load/store in parallel with ALU theoretically

    // TODO: send logic to ALU!



    // mem_stage
//     always_ff @(posedge clk or negedge rst) begin
//         if(~rst) begin
//             vr_en[2]    <= 0;
//         end else begin
//             vr_en[2]    <= en_vd || en_vs3;
//             if (en_vd) begin
//               vr_rw[2]    <= 1;
//             end
//             if (en_vs3) begin
//               vr_rw[2]    <= 0;
//             end
//         end
//     end

    // TODO: writeback logic

endmodule