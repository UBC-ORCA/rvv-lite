module addr_gen_unit #(
    parameter VLEN          = 16384,
    parameter DATA_WIDTH    = 64,
    parameter ADDR_WIDTH    = 5,    // this gives us 32 vectors
    parameter OFF_WIDTH     = $clog2(VLEN/DATA_WIDTH)
) (
    // FIXME for avl of uneven length across regs
    // no data reset needed, if the user picks an unused register they get garbage data and that's their problem ¯\_(ツ)_/¯
    input                       clk,
    input                       rst_n,
    input                       en,
    input                       ack,
    input   [           1:0]    sew,
    input   [ OFF_WIDTH-1:0]    max_off_in,
    input   [           2:0]    max_reg_in,
    input   [ADDR_WIDTH-1:0]    addr_in,   // register group address
    input                       whole_reg,
    input                       widen,
    input   [ OFF_WIDTH-1:0]    off_in,
    output  [ADDR_WIDTH-1:0]    addr_out, // output of v_reg address
    output  [ OFF_WIDTH-1:0]    off_out,
    output                      addr_start,
    output                      addr_end,
    output                      idle      // signal to processor that we can get another address
);
    // TODO fractional lmul support would change this up

    reg  [ADDR_WIDTH-1:0]   base_reg;
    reg  [           2:0]   curr_reg, max_reg;
    reg  [ OFF_WIDTH-1:0]   curr_off, max_off;
    reg                     state;  // STATES: IDLE, BUSY
    reg                     turn;   // widening
    wire                    turn_next;
    wire                    state_next;
    wire [ADDR_WIDTH-1:0]   base_reg_out;
    wire [           2:0]   curr_reg_out, max_reg_out;
    wire [ OFF_WIDTH-1:0]   curr_off_out, max_off_out;

    assign addr_out         = base_reg_out + curr_reg_out;
    assign off_out          = curr_off_out;
    assign idle             = (widen & ~en & ~state) | (~widen & ~state_next);

    assign state_next       = rst_n & (en | (state & (curr_reg != max_reg | curr_off != max_off | (widen & ~turn))));

    assign addr_start       = (~state | (curr_reg == max_reg & curr_off == max_off & (~widen | turn))) & en; // start of addr when en in idle state or when en while resetting
    assign addr_end         = (state & curr_reg_out == max_reg_out & curr_off_out == max_off_out & (~widen | turn));

    assign base_reg_out    = (addr_start ? addr_in : base_reg);
    assign curr_reg_out    = (~addr_start & state_next) ? (curr_reg + (curr_reg != max_reg & (curr_off == max_off) & (~widen | ~turn))) : 'h0;
    assign max_reg_out     = (addr_start ? (whole_reg ? (1 << sew) - 1 : max_reg_in) : max_reg);

    assign curr_off_out    = (~addr_start & ((state_next & ~widen) | (state & widen))) & (curr_off != max_off | widen) ? (curr_off + (curr_off != max_off & (~widen | ~turn))) : (addr_start ? off_in : 'h0);
    assign max_off_out     = (addr_start ? (whole_reg ? (VLEN/DATA_WIDTH) - 1 : max_off_in) : max_off);

    assign turn_next        = widen & (en | state) ? ~turn : 0;

    // latching input values
    always @(posedge clk) begin
      if (ack) begin
        base_reg    <= base_reg_out;
        curr_reg    <= curr_reg_out;
        max_reg     <= max_reg_out;
        curr_off    <= curr_off_out;
        max_off     <= max_off_out;
        state       <= state_next;
        turn        <= turn_next;
      end

      if (~rst_n) begin
        base_reg    <= 0;
        curr_reg    <= 0;
        max_reg     <= 0;
        curr_off    <= 0;
        max_off     <= 0;
        state       <= 0;
        turn        <= 0;
      end
    end
endmodule
