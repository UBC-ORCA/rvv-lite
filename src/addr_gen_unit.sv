module addr_gen_unit #(
    parameter VLEN          = 16384,
    parameter DATA_WIDTH    = 64,
    parameter ADDR_WIDTH    = 5,    // this gives us 32 vectors
    parameter OFF_WIDTH     = 8
) (
    // FIXME for avl of uneven length across regs
    // no data reset needed, if the user picks an unused register they get garbage data and that's their problem ¯\_(ツ)_/¯
    input                       clk,
    input                       rst_n,
    input                       en,
    input   [           1:0]    sew,
    input   [ OFF_WIDTH-1:0]    max_off_in,
    input   [           2:0]    max_reg_in,
    input   [ADDR_WIDTH-1:0]    addr_in,   // register group address
    input                       whole_reg,
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
    wire                    state_next;
    wire [ADDR_WIDTH-1:0]   base_reg_out;
    wire [           2:0]   curr_reg_out, max_reg_out;
    wire [ OFF_WIDTH-1:0]   curr_off_out, max_off_out;

    assign addr_out         = base_reg_out + curr_reg_out;
    assign off_out          = curr_off_out;
    assign idle             = ~state_next;

    assign state_next       = rst_n & (en | (state & (curr_reg != max_reg | curr_off != max_off)));

    assign addr_start       = (~state | (curr_reg == max_reg & curr_off == max_off)) & en; // start of addr when en in idle state or when en while resetting
    // assign addr_end         = ((sew[2] | ~(|sew)) & en) | (state_next & curr_reg_out == max_reg_out & curr_off_out == max_off_out);
    assign addr_end         = (state_next & curr_reg_out == max_reg_out & curr_off_out == max_off_out);

    assign base_reg_out    = (addr_start ? addr_in : base_reg);
    assign curr_reg_out    = ~addr_start ? (curr_reg + (curr_reg != max_reg & (curr_off == max_off))) : 'h0;
    // assign max_reg_out     = (addr_start ? (~sew[2] ? max_reg_in : (max_reg_in >> (3'b100 - sew[1:0]))) : max_reg);
    assign max_reg_out     = (addr_start ? (whole_reg ? (1 << sew) - 1 : max_reg_in) : max_reg);

    assign curr_off_out    = ~addr_start & (curr_off != max_off) ? (curr_off + (curr_off != max_off)) : 'h0;
    // assign max_off_out     = (addr_start ? (~sew[2] ? max_off_in : (max_off_in >> (3'b100 - sew[1:0]))) : max_off);
    assign max_off_out     = (addr_start ? (whole_reg ? (VLEN/DATA_WIDTH) - 1 : max_off_in) : max_off);

    // latching input values
    always @(posedge clk) begin
        base_reg    <= base_reg_out;
        curr_reg    <= curr_reg_out;
        max_reg     <= max_reg_out;

        curr_off    <= curr_off_out;
        max_off     <= max_off_out;

        state       <= state_next;
    end
endmodule