module vAndOrXor 
  #(
    parameter REQ_DATA_WIDTH    = 64,
    parameter RESP_DATA_WIDTH   = 64,
    parameter REQ_ADDR_WIDTH    = 32,
    parameter OPSEL_WIDTH       = 3,
    parameter VEC_MOVE_ENABLE   = 1,
    parameter WHOLE_REG_ENABLE  = 1,
    parameter MASK_ENABLE       = 1
  ) 
  (
    input  logic clk,
    input  logic rst,
    input  logic [REQ_ADDR_WIDTH-1:0] in_addr,
    input  logic [REQ_DATA_WIDTH-1:0] in_vec0,
    input  logic [REQ_DATA_WIDTH-1:0] in_vec1,
    input  logic in_valid,
    input  logic [OPSEL_WIDTH-1:0] in_opSel, //01=and,10=or,11=xor
    input  logic in_sca,
    input  logic in_w_reg,
    input  logic in_mask,
    output logic [RESP_DATA_WIDTH-1:0] out_vec,
    output logic out_valid,
    output logic [REQ_ADDR_WIDTH-1:0] out_addr,
    output logic out_w_reg,
    output logic out_sca,
    output logic out_mask
  );

    localparam NUM_STAGES = 6;
    logic [REQ_ADDR_WIDTH-1:0] addrs[NUM_STAGES];
    logic [REQ_DATA_WIDTH-1:0] vecs[NUM_STAGES];
    logic valids[NUM_STAGES];
    logic masks[NUM_STAGES];
    logic scas[NUM_STAGES];
    logic w_regs[NUM_STAGES];

    logic [REQ_DATA_WIDTH-1:0] vec;

    always_comb begin
      //default
      vec = REQ_DATA_WIDTH'(0);

      if (MASK_ENABLE) begin
        unique case(in_opSel)
          3'b000: vec <=   in_vec0  & ~in_vec1;
          3'b001: vec <=   in_vec0  &  in_vec1;
          3'b010: vec <=   in_vec0  |  in_vec1;
          3'b011: vec <=   in_vec0  ^  in_vec1;
          3'b100: vec <=   in_vec0  | ~in_vec1;
          3'b101: vec <= ~(in_vec0  &  in_vec1);
          3'b110: vec <= ~(in_vec0  |  in_vec1);
          3'b111: vec <= ~(in_vec0  ^  in_vec1);
        endcase
      end else begin
        unique case(in_opSel[1:0])
          2'b01: vec <=    in_vec0  &  in_vec1;
          2'b10: vec <=    in_vec0  |  in_vec1;
          2'b11: vec <=    in_vec0  ^  in_vec1;
        endcase
      end
    end

    always_ff @(posedge clk) begin
      addrs[0]  <= in_valid ? in_addr : REQ_ADDR_WIDTH'(0);
      vecs[0]   <= in_valid ? vec : REQ_DATA_WIDTH'(0);
      valids[0] <= in_valid;
      if (MASK_ENABLE)
        masks[0]  <= in_valid ? in_mask : 1'b0;
      if (VEC_MOVE_ENABLE) begin
        scas[0]   <= in_valid ? in_sca : 1'b0;
        if (WHOLE_REG_ENABLE)
          w_regs[0] <= in_valid ? in_w_reg : 1'b0;
      end

      for (int s = 1; s < NUM_STAGES; s++) begin
        addrs[s]  <= addrs[s-1];
        vecs[s]   <= vecs[s-1];
        valids[s] <= valids[s-1];
        if (MASK_ENABLE)
          masks[s]  <= masks[s-1];
        if (VEC_MOVE_ENABLE) begin
          scas[s]   <= scas[s-1];
          if (WHOLE_REG_ENABLE)
            w_regs[s] <= w_regs[s-1];
        end
      end

      if (rst) begin
        for (int s = 0; s < NUM_STAGES; s++) begin
          addrs[s]  <= REQ_ADDR_WIDTH'(0);
          vecs[s]   <= REQ_DATA_WIDTH'(0);
          valids[s] <= 1'b0;
          if (MASK_ENABLE)
            masks[s]  <= 1'b0;
          if (VEC_MOVE_ENABLE) begin
            scas[s]   <= 1'b0;
            if (WHOLE_REG_ENABLE)
              w_regs[s] <= 1'b0;
          end
        end
      end
    end

    assign out_addr  = addrs[NUM_STAGES-1];
    assign out_vec   = vecs[NUM_STAGES-1];
    assign out_valid = valids[NUM_STAGES-1];
    assign out_mask  = MASK_ENABLE ? masks[NUM_STAGES-1] : 1'b0;
    assign out_sca   = VEC_MOVE_ENABLE ? scas[NUM_STAGES-1] : 1'b0;
    assign out_w_reg = VEC_MOVE_ENABLE && WHOLE_REG_ENABLE ? w_regs[NUM_STAGES-1] : 1'b0;

endmodule
