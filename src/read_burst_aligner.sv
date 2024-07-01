module read_burst_aligner
  #(
    parameter int DATA_WIDTH = 64
  )
  ( 
    input  logic clk,
    input  logic rst,

    input  logic i_valid,
    input  logic i_start,
    input  logic i_end,
    input  logic [DATA_WIDTH-1:0] i_data,
    input  logic [$clog2(DATA_WIDTH/8)-1:0] i_shamt,
    output logic o_valid,
    output logic o_start,
    output logic o_end,
    output logic [DATA_WIDTH-1:0] o_data,
    output logic o_idle
  );

  logic [2*DATA_WIDTH-1:0] padded_data;
  logic [DATA_WIDTH-1:0] remainder_data;
  logic [DATA_WIDTH-1:0] result_data;
  logic [DATA_WIDTH-1:0] result_data_r;
  logic busy;

  enum int unsigned {S_START, S_WAIT, S_END} state, nstate;

  always_ff @(posedge clk) begin
    if (i_valid) begin
      result_data_r <= result_data;
    end

    if (rst) begin
      result_data_r <= '0;
    end
  end

  always_ff @(posedge clk) begin
    state <= nstate;

    if (rst) begin
      state <= S_START;
    end
  end

  always_comb begin
    // defaults
    nstate = state;

    unique case (state)
      S_START: begin
        if (i_valid && i_start) begin
          if (|i_shamt) begin 
            nstate = S_WAIT;
          end else begin
            nstate = S_END;
          end
          if (i_end) begin
            nstate = S_START;
          end
        end
      end

      S_WAIT: begin
        if (i_valid) begin
          nstate = S_END;
          if (i_end) begin
            nstate = S_START;
          end
        end
      end

      S_END: begin
        if (i_valid && i_end) begin
          nstate = S_START;
        end
      end

    endcase
  end

  assign padded_data = {i_data, DATA_WIDTH'(0)};
  assign {result_data, remainder_data} = padded_data >> i_shamt*8;

  assign busy    = state == S_START ? i_valid && i_start :
                   state == S_END   ? 1'b1 :
                   state == S_WAIT  ? 1'b1 :
                   1'b0;

  assign o_data  = i_valid && i_shamt == '0 ? result_data :
                   remainder_data | result_data_r;
  assign o_valid = state == S_START ? i_valid && i_start && i_shamt == '0 :
                   state == S_WAIT  ? i_valid :
                   state == S_END   ? i_valid :
                   1'b0;
  assign o_start = state == S_START ? i_valid && i_start && i_shamt == '0 :
                   state == S_WAIT  ? i_valid :
                   state == S_END   ? 1'b0 :
                   1'b0;
  assign o_end   = i_valid && i_end;
  assign o_idle  = ~busy;

endmodule: read_burst_aligner

