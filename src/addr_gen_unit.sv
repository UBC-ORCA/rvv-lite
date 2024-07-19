module addr_gen_unit 
  #(
    parameter VLEN          = 16384,
    parameter DATA_WIDTH    = 64,
    parameter ADDR_WIDTH    = 5,    // this gives us 32 vectors
    parameter OFF_WIDTH     = $clog2(VLEN/DATA_WIDTH)
  ) 
  (
    // TODO fractional lmul support would change this up
    // no data reset needed, if the user picks an unused register they get garbage data and that's their problem ¯\_(ツ)_/¯
    input  logic clk,
    input  logic rst,
    input  logic en,
    input  logic ack,
    input  logic widen_in,
    input  logic [ OFF_WIDTH-1:0] off_in,
    input  logic [ OFF_WIDTH-1:0] max_off_in,
    input  logic [ADDR_WIDTH-1:0] addr_in,          // register group address
    input  logic [ADDR_WIDTH-1:0] max_reg_in,
    output logic [ADDR_WIDTH-1:0] addr_out,         // output of v_reg address
    output logic [ OFF_WIDTH-1:0] off_out,
    output logic addr_valid,
    output logic addr_start,
    output logic addr_end,
    output logic idle                               // signal to processor that we can get another address
  );

  logic [ADDR_WIDTH+OFF_WIDTH-1:0] start_count_in, end_count_in;

  always_comb begin
    start_count_in = {addr_in, off_in};
    end_count_in   = {addr_in + max_reg_in, max_off_in};
  end

  enum int unsigned {S_IDLE, S_WAIT, S_COUNT} state, nstate;

  logic [ADDR_WIDTH+OFF_WIDTH-1:0] count, ncount;
  logic [ADDR_WIDTH+OFF_WIDTH-1:0] end_count, nend_count;
  logic widen, nwiden;
  logic busy;

  always_comb begin
    // defaults
    nstate = state;
    ncount = count;
    nend_count = end_count;
    nwiden = widen;

    unique case (state)
      S_IDLE: begin
        if (en) begin
          ncount = start_count_in;
          nend_count = end_count_in;
          nwiden = widen_in;

          if (widen_in) begin
            nstate = S_WAIT;
          end else if (start_count_in != end_count_in) begin
            nstate = S_COUNT;
          end
        end
      end

      S_WAIT: begin
        nstate = S_COUNT;

        if (count == end_count) begin
          nstate = S_IDLE;
        end
      end

      S_COUNT: begin
        ncount = count + 1;

        if (widen) begin
          nstate = S_WAIT;
        end else if (count + 1 == end_count) begin
          nstate = S_IDLE;
        end
      end
    endcase
  end

  always_ff @(posedge clk) begin
    if (ack) begin
      state <= nstate;
      count <= ncount;
      end_count <= nend_count;
      widen <= nwiden;
    end

    if (rst) begin
      state <= S_IDLE;
      count <= 0;
      end_count <= 0;
      widen <= 0;
    end
  end

  // Outputs
  assign busy         = state == S_WAIT  ? 1'b1 :
                        state == S_COUNT ? 1'b1 :
                        1'b0;
  assign addr_start   = state == S_IDLE  ? en :
                        state == S_WAIT  ? 1'b0 :
                        state == S_COUNT ? 1'b0 :
                        1'b0;
  assign addr_end     = state == S_IDLE  ? en && ~widen_in && start_count_in == end_count_in :
                        state == S_WAIT  ? count == end_count :
                        state == S_COUNT ? ~widen && count + 1 == end_count :
                        1'b0;
  assign addr_valid   = state == S_IDLE  ? en :
                        state == S_WAIT  ? 1'b1 :
                        state == S_COUNT ? 1'b1 :
                        1'b0;
  assign idle         = ~busy;
  assign {addr_out, off_out} = ncount;

endmodule
