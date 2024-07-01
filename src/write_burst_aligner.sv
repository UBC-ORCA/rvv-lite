module write_burst_aligner
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
    input  logic [DATA_WIDTH/8-1:0] i_be,
    input  logic [$clog2(DATA_WIDTH/8)-1:0] i_shamt,
    output logic o_valid,
    output logic o_start,
    output logic o_end,
    output logic [DATA_WIDTH-1:0] o_data,
    output logic [DATA_WIDTH/8-1:0] o_be,
    output logic o_idle
  );

  logic [2*DATA_WIDTH-1:0] padded_data;
  logic [DATA_WIDTH-1:0] result_data;
  logic [DATA_WIDTH-1:0] remainder_data;
  logic [DATA_WIDTH-1:0] remainder_data_r;
  logic [2*(DATA_WIDTH/8)-1:0] padded_be;
  logic [DATA_WIDTH/8-1:0] result_be;
  logic [DATA_WIDTH/8-1:0] remainder_be;
  logic [DATA_WIDTH/8-1:0] remainder_be_r;
  logic [$clog2(DATA_WIDTH/8)-1:0] shamt_r;
  logic [DATA_WIDTH/8-1:0] be_r;
  logic busy;

  enum int unsigned {S_START, S_WAIT, S_END} state, nstate;

  always_ff @(posedge clk) begin
    if (i_valid) begin
      remainder_data_r <= remainder_data;
      remainder_be_r <= remainder_be;
      if (i_start) begin
        shamt_r <= i_shamt;
        be_r <= i_be;
      end
    end

    if (rst) begin
      remainder_data_r <= '0;
      remainder_be_r <= '0;
      shamt_r <= '0;
      be_r <= '0;
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
          nstate = S_END;

          if (i_end) begin
            if (|i_shamt) begin
              nstate = S_WAIT;
            end
          end
        end
      end

      S_END: begin
        if (i_valid && i_end) begin
          if (|shamt_r) begin
            nstate = S_WAIT;
          end else begin
            nstate = S_START;
          end
        end
      end

      S_WAIT: begin
        nstate = S_START;
      end

    endcase
  end

  assign padded_data = {DATA_WIDTH'(0), i_data};
  assign {remainder_data, result_data} = padded_data << (state == S_START ? i_shamt : shamt_r)*8;
  assign padded_be = {(DATA_WIDTH/8)'(0), i_be};
  assign {remainder_be, result_be} = padded_be << (state == S_START ? i_shamt : shamt_r);

  assign busy    = state == S_START ? i_valid && i_start :
                   state == S_END   ? 1'b1 :
                   state == S_WAIT  ? 1'b1 :
                   1'b0;

  assign o_valid = state == S_START ? i_valid : 
                   state == S_END   ? i_valid :
                   state == S_WAIT  ? 1'b1 :
                   1'b0;
  assign o_start = i_valid && i_start;
  assign o_end   = state == S_START ? i_valid && i_end && i_shamt == '0 :
                   state == S_END   ? i_valid && i_end && shamt_r == '0 :
                   state == S_WAIT  ? 1'b1 :
                   1'b0;
  assign o_data  = state == S_START ? result_data :
                   state == S_END   ? result_data | remainder_data_r : 
                   state == S_WAIT  ? remainder_data_r :
                   '0;
  assign o_be    = state == S_START ? result_be :
                   state == S_END   ? {DATA_WIDTH/8{1'b1}} :
                   state == S_WAIT  ? remainder_be_r :
                   '0;
  assign o_idle  = ~busy;


endmodule : write_burst_aligner
