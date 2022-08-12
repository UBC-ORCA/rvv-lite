module mem_addr_gen_unit #(
    parameter ADDR_WIDTH = 5,    // this gives us 32 vectors
    parameter OFF_WIDTH = 8,
    parameter MEM_ADDR_WIDTH = 32,
    parameter VEX_DATA_WIDTH = 32,
    parameter SEW_WIDTH = 3,
    parameter DATA_WIDTH = 64,
    parameter DATA_WIDTH_BITS = 6,
    parameter DW_B      = 8,
    parameter DW_B_BITS = 3
) (
    // no data reset needed, if the user picks an unused register they get garbage data and that's their problem ¯\_(ツ)_/¯
    input                       clk,
    input                       rst_n,
    input                       en,
    input   [ SEW_WIDTH-1:0]    sew,
    input   [MEM_ADDR_WIDTH-1:0]addr_in,   // base memory address to read from
    input   [DATA_WIDTH-1:0]    vec_in,     // input vector
    input   [VEX_DATA_WIDTH-1:0]stride_in,
    output  [ADDR_WIDTH-1:0]    addr_out, // output of v_addr address
    output  [ OFF_WIDTH-1:0]    off_out,
    output                      addr_start,
    output                      addr_end,
    output                      idle      // signal to processor that we can get another address
);
    // TODO fractional lmul support would change this up

    reg  [ADDR_WIDTH-1:0]   base_addr;
    reg  [ SEW_WIDTH-1:0]   curr_addr, max_addr;
    reg  [ OFF_WIDTH-1:0]   curr_off, max_off;
    reg                     state;  // STATES: IDLE, BUSY
    wire                    state_next;
    wire [ADDR_WIDTH-1:0]   base_addr_out;
    wire [ SEW_WIDTH-1:0]   curr_addr_out, max_addr_out;
    wire [ OFF_WIDTH-1:0]   curr_off_out, max_off_out;

    wire [DATA_WIDTH-1:0]   addr_off;

    assign addr_out         = base_addr_out + curr_addr_out;
    assign off_out          = curr_off_out;
    assign idle             = ~state_next;

    assign addr_off         = DW_B;

    assign state_next       = rst_n & (en | (state & curr_addr != max_addr));

    assign addr_start       = (~state | (curr_addr == max_addr)) & en; // start of addr when en in idle state or when en while resetting
    assign addr_end         = (en) | (state_next & curr_addr_out == max_addr_out);

    assign base_addr_out    = (addr_start ? addr_in : base_addr);
    assign curr_addr_out    = addr_start ? 'h0 : (curr_addr + DW_B);
    assign max_addr_out     = (addr_start ? max_addr_in : max_addr);

    assign curr_off_out    = addr_start | (curr_off == max_off) ? 'h0 : (curr_off + (curr_off != max_off));
    assign max_off_out     = (addr_start ? max_off_in : max_off);

    // for indexed, this will be more difficult for SEW = 8 and SEW = 16. 32 and 64 will be very straightforward.

    // latching input values
    always @(posedge clk) begin
        base_addr    <= base_addr_out;
        curr_addr    <= curr_addr_out;
        max_addr     <= max_addr_out;

        curr_off    <= curr_off_out;
        max_off     <= max_off_out;

        state       <= state_next;
    end
endmodule