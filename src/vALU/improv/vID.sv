module vID 
  #(
    parameter REQ_BYTE_EN_WIDTH = 8,
    parameter REQ_DATA_WIDTH    = 64,
    parameter RESP_DATA_WIDTH   = 64,
    parameter REQ_ADDR_WIDTH    = 5,
    parameter ENABLE_64_BIT     = 1
  ) 
  (
    input  logic clk,
    input  logic rst,
    input  logic [REQ_ADDR_WIDTH-1:0] in_addr,
    input  logic [1:0] in_sew,
    input  logic in_valid,
    input  logic [11:0] in_start_idx,
    output logic [REQ_ADDR_WIDTH-1:0] out_addr,
    output logic [RESP_DATA_WIDTH-1:0] out_vec,
    output logic out_valid
  );

    localparam NUM_STAGES = 6;
    logic [REQ_ADDR_WIDTH-1:0] addrs[NUM_STAGES];
    logic [REQ_DATA_WIDTH-1:0] vecs[NUM_STAGES];
    logic valids[NUM_STAGES];

    logic [REQ_DATA_WIDTH-1:0] vec;

    always_comb begin
      unique case (in_sew)
        2'b00: begin
          for (int i = 0; i < REQ_DATA_WIDTH/8; i++)
            vec[ 8*i +:  8] = in_start_idx + i;
        end

        2'b01: begin
          for (int i = 0; i < REQ_DATA_WIDTH/16; i++)
            vec[16*i +: 16] = in_start_idx + i;
        end

        2'b10: begin
          for (int i = 0; i < REQ_DATA_WIDTH/32; i++)
            vec[32*i +: 32] = in_start_idx + i;
        end

        2'b11: begin
          for (int i = 0; i < REQ_DATA_WIDTH/64; i++)
            vec[64*i +: 64] = in_start_idx + i;

          if (ENABLE_64_BIT == 0)
            vec = REQ_DATA_WIDTH'(0);
        end
      endcase
    end

    always_ff @(posedge clk) begin
      addrs[0]  <= in_valid ? in_addr : REQ_ADDR_WIDTH'(0);
      vecs[0]   <= in_valid ? vec : REQ_DATA_WIDTH'(0);
      valids[0] <= in_valid;

      for (int s = 1; s < NUM_STAGES; s++) begin
        addrs[s]  <= addrs[s-1];
        vecs[s]   <= vecs[s-1];
        valids[s] <= valids[s-1];
      end

      if (rst) begin
        for (int s = 0; s < NUM_STAGES; s++) begin
          addrs[s]  <= REQ_ADDR_WIDTH'(0);
          vecs[s]   <= REQ_DATA_WIDTH'(0);
          valids[s] <= 1'b0;
        end
      end
    end

    assign out_addr  = addrs[NUM_STAGES-1];
    assign out_vec   = vecs[NUM_STAGES-1];
    assign out_valid = valids[NUM_STAGES-1];

endmodule
