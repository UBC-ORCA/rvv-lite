module vcfg 
  import opcodes::*;
  #(
    parameter XLEN          = 32,
    parameter VLEN          = 16384,
    parameter VLMAX         = VLEN/8,
    parameter VL_BITS       = $clog2(VLMAX)+1, // 0 -> VLMAX
    parameter ENABLE_64_BIT = 1
  ) 
  (
    input  logic clk,
    input  logic rst,
    input  logic valid,
    input  vcfg_instruction_t insn,
    input  logic [XLEN-1:0] rf[1:2],

    output logic [VL_BITS-1:0] vl,
    output vtype_t vtype
  );

  logic [XLEN-1:0] avl;
  logic [VL_BITS-1:0] nvl;
  vtype_t nvtype;

  always_comb begin
    unique casez (insn)
      VSETIVLI: nvtype = (XLEN)'(insn[29:20]);
      VSETVLI : nvtype = (XLEN)'(insn[30:20]);
      VSETVL  : nvtype = rf[2];
      default : nvtype = 0;
    endcase
    
    if (nvtype.vill == 1'b1 ||                                        // illegal vtype 
          nvtype.zeros != 23'b0 ||                                    // reserved vtype
            nvtype.vsew > 3'($clog2((ENABLE_64_BIT ? 64 : 32)/8)) ||  // VSEW > ELEN
              nvtype.vsew != nvtype.vlmul ||                          // VSEW/VLMUL != 8
                nvtype.vma == 1'b1)                                   // mask agnostic
      nvtype = '{vill: 1'b1, default: '0};
  end

  always_comb begin
    unique casez (insn)
      VSETIVLI: begin 
        avl = (XLEN)'(insn[19:15]);

        // stripmining not needed
        nvl = avl[VL_BITS-1:0];                              
      end

      VSETVLI, VSETVL: begin
        if (insn.rs1_addr != 5'd0) begin
          avl = rf[1];
        end else if (insn.rd_addr != 5'd0) begin
          avl = {XLEN{1'b1}};
        end else begin
          avl = (XLEN)'(vl);
        end

        // stripmining
        nvl = avl > VLMAX ? VLMAX[VL_BITS-1:0] : avl[VL_BITS-1:0];
      end

      default: begin
        avl = 0;
        nvl = 0;
      end
    endcase

    if (nvtype.vill == 1'b1)
      nvl = 0;
  end

  always_ff @(posedge clk) begin
    if (valid) begin
      vtype <= nvtype;
      vl <= nvl;
    end

    if (rst) begin
      vtype <= 0;
      vl <= 0;
    end
  end

endmodule
