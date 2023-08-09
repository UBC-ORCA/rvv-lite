module vAdd_unit_block 
  #(
    parameter REQ_DATA_WIDTH = 64,
    parameter RESP_DATA_WIDTH = 64,
    parameter SEW_WIDTH = 2,
    parameter OPSEL_WIDTH = 5,
    parameter ENABLE_64_BIT = 1
  ) 
  (
    input  logic clk,
    input  logic rst,
    input  logic [REQ_DATA_WIDTH-1:0] vec0,
    input  logic [REQ_DATA_WIDTH-1:0] vec1,
    input  logic [REQ_DATA_WIDTH-1:0] carry,
    input  logic [SEW_WIDTH-1:0] sew,
    input  logic [OPSEL_WIDTH-1:0] opSel,
    output logic [RESP_DATA_WIDTH+16:0] result
    );

    genvar i;

    logic [REQ_DATA_WIDTH-1:0] w_vec0, w_vec1;
    logic [REQ_DATA_WIDTH+(1+1)*8-1:0] w_op0, w_op1;
    logic [REQ_DATA_WIDTH/8-1:0] v0_sgn, v1_sgn;
    logic [REQ_DATA_WIDTH/8-1:0] v0_ext, v1_ext;

    /*
     * opSel[1:0] == vAdd_opSel
     * vMinMax_en or vMComp_en (1) -> vAdd_opSel = 2'b10 ->  vec0 - vec1
     *                         (0) -> 2'b00 (vadd) - 2'b01 (reserved) - 2'b10 (vsub) - 2'b11 (vrsub)
    */
    assign w_vec0 = opSel[1:0] == 2'b11 ? ~vec0 : vec0;
    assign w_vec1 = opSel[1:0] == 2'b10 ? ~vec1 : vec1;

    /* ?????????????????????????
     * opSel[4] == vMinMax_opSel
     * opSel[2] == vSigned_op0
    */
    always_comb begin
      unique casez ({opSel[4], opSel[2]})
        2'b0?: begin
          v0_sgn = {REQ_DATA_WIDTH/8{1'b1}};
          v1_sgn = {REQ_DATA_WIDTH/8{1'b0}};
        end

        2'b10: begin  // vminu, vmaxu
          v0_sgn = {REQ_DATA_WIDTH/8{1'b0}};
          v1_sgn = {REQ_DATA_WIDTH/8{1'b1}};
        end

        2'b11: begin  // vmin, vmax
          for(int i = 0; i < REQ_DATA_WIDTH/8; i++) begin
            v0_sgn[i] =  vec0[8*(i+1)-1];
            v1_sgn[i] = ~vec1[8*(i+1)-1];
          end
        end
      endcase
    end

    /*
     * 0 -> carry-kill if addition        -> ext = 2'b00
     *      carry-generate if subtraction -> ext = 2'b11
     * 1 -> carry-propagate               -> ext = 2'b01 | 2'b10
    */
    logic [8-1:0] msk;

    always_comb begin
      unique case (sew)
        2'b00: msk = 8'b00000000;
        2'b01: msk = 8'b10101010;
        2'b10: msk = 8'b11101110;
        2'b11: msk = ENABLE_64_BIT ? 8'b11111110: 8'b11101110;
      endcase
    end

    /*
     * opSel[1] == is_sub
    */
    for (i = 0; i < REQ_DATA_WIDTH/8; i++) begin
      assign v0_ext[i] = opSel[1];
      assign v1_ext[i] = opSel[1] ^ msk[i];
    end

    for (i = 0; i < (REQ_DATA_WIDTH >= 64 ? 8 : 4); i++) begin
      assign w_op0[(1+8+1)*i +: (1+8+1)] = {v0_sgn[i], w_vec0[8*i +: 8], v0_ext[i]};
      assign w_op1[(1+8+1)*i +: (1+8+1)] = {v1_sgn[i], w_vec1[8*i +: 8], v1_ext[i]};
    end

    if (ENABLE_64_BIT) begin
      assign result = w_op0 + w_op1 + carry;
    end else begin
      assign result[REQ_DATA_WIDTH/2 +: REQ_DATA_WIDTH/2] = w_op0[REQ_DATA_WIDTH/2+8 +: REQ_DATA_WIDTH/2+8] + 
                                                            w_op1[REQ_DATA_WIDTH/2+8 +: REQ_DATA_WIDTH/2+8] + 
                                                            carry[REQ_DATA_WIDTH/2   +: REQ_DATA_WIDTH/2];
      assign result[0 +: REQ_DATA_WIDTH/2]  =   w_op0[0 +: REQ_DATA_WIDTH/2+8] + 
                                                w_op1[0 +: REQ_DATA_WIDTH/2+8] + 
                                                carry[0 +: REQ_DATA_WIDTH/2];
    end

endmodule
