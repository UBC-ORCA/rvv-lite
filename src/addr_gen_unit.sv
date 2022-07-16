module addr_gen_unit #(
    parameter ADDR_WIDTH = 5    // this gives us 32 vectors
) (
    // no data reset needed, if the user picks an unused register they get garbage data and that's their problem ¯\_(ツ)_/¯
    input                       clk,
    input                       rst_n,
    input                       en,
    input   [2:0]               vlmul,
    input   [ADDR_WIDTH-1:0]    addr_in,   // register group address
    output  [ADDR_WIDTH-1:0]    addr_out, // output of v_reg address
    output                      addr_start,
    output                      addr_end,
    output                      idle      // signal to processor that we can get another address
);

    reg  [ADDR_WIDTH-1:0]   base_reg;
    reg  [           2:0]   curr_reg;
    reg  [           2:0]   max_reg;
    reg                     state;  // STATES: IDLE, BUSY
    wire                    reg_group, new_addr, state_next;
    wire                    addr_start_out, addr_end_out;
    wire [ADDR_WIDTH-1:0]   base_reg_out;
    wire [           2:0]   curr_reg_out, max_reg_out;

    assign reg_group        = ~vlmul[2] & (vlmul[1] | vlmul[0]);
    assign addr_out         = base_reg_out + curr_reg_out;
    assign idle             = ~state_next;

    assign state_next       = rst_n & (en | (state & curr_reg !== max_reg));

    assign new_addr         = (~state | curr_reg === max_reg) & en;

    assign addr_start       = (~state | curr_reg === max_reg) & en; // start of addr when en in idle state or when en while resetting
    assign addr_end         = ((vlmul[2] | vlmul === 'b0) & en) | (state_next & curr_reg_out === max_reg);

    assign base_reg_out    = {ADDR_WIDTH{rst_n}} & (new_addr ? addr_in : base_reg);
    assign curr_reg_out    = {3{rst_n & ~new_addr}} & (curr_reg + (curr_reg !== max_reg));
    assign max_reg_out     = {3{rst_n}} & (new_addr ? ({3{~vlmul[2]}} & {vlmul[1] & vlmul[0], vlmul[1], vlmul[1] | vlmul[0]}) : max_reg);

    // latching input values
    always @(posedge clk) begin
        base_reg    <= base_reg_out;
        curr_reg    <= curr_reg_out;
        max_reg     <= max_reg_out;

        state       <= state_next;
    end
endmodule