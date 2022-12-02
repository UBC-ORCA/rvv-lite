module addr_gen_unit #(
    parameter ADDR_WIDTH = 5    // this gives us 32 vectors
) (
    // no data reset needed, if the user picks an unused register they get garbage data and that's their problem ¯\_(ツ)_/¯
    input                       clk,
    input                       rst_n,
    input                       en,
    input                       widen,
    input   [2:0]               vlmul,
    input   [ADDR_WIDTH-1:0]    addr_in,   // register group address
    output  [ADDR_WIDTH-1:0]    addr_out, // output of v_reg address
    output  reg                 addr_start,
    output  reg                 addr_end,
    output                      idle      // signal to processor that we can get another address
);

    reg                  turn;
    reg [ADDR_WIDTH-1:0] curr_reg, next_reg;
    reg [ADDR_WIDTH-1:0] max_reg;
    reg state;  // STATES: IDLE, BUSY

//   assign reg_group = (vlmul > 3'b000 && vlmul[2] === 1'b0);
    assign addr_out         = curr_reg;
    // assign idle_single_addr = (vlmul[2] && ~en);
    assign idle             = ~(state | en);

    // assign addr_start       = (~state | curr_reg === max_reg) & en; // start of addr when en in idle state or when en while resetting
    // assign addr_end         = ((vlmul[2] | vlmul === 'b0) & en) | (state & curr_reg === max_reg);

    always @(*) begin
        curr_reg = (state & curr_reg < max_reg) ? next_reg : addr_in;
    end

    // latching input values
    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            next_reg    <= 0;
            max_reg     <= 0;
            addr_start  <= 0;
            addr_end    <= 0;
            turn        <= 0;
        end else begin
            if (state == 1'b0) begin
                if (en) begin
                    // curr_reg <= (vlmul[2] === 1'b0) ? addr_in << vlmul : addr_in;
                    next_reg    <= widen ? addr_in : addr_in + 1;
                    // max_reg <= (vlmul[2] === 1'b0) ? (addr_in << vlmul) + (1'b1 << vlmul) - 1'b1 : addr_in;
                    max_reg     <= (vlmul[2] === 1'b0) ? addr_in + (1'b1 << vlmul) - 1'b1 : addr_in;

                    turn        <= widen ? 1 : 0;
                end
            end else begin
                if (next_reg === max_reg) begin
                    if (en) begin
                        // curr_reg <= (vlmul[2] === 1'b0) ? addr_in << vlmul : addr_in;
                        // max_reg <= (vlmul[2] === 1'b0) ? (addr_in << vlmul) + (1'b1 << vlmul) - 1'b1 : addr_in;
                        next_reg    <= widen & ~turn ? next_reg : addr_in;
                        max_reg     <= (vlmul[2] === 1'b0 & (~widen | turn)) ? addr_in + (1'b1 << vlmul) - 1'b1 : addr_in;
                        turn        <= widen & ~turn ? ~turn    : 0;
                    end
                end else begin
                    next_reg    <= widen & ~turn ? next_reg : next_reg + 1;
                    turn        <= widen ? ~turn : 0;
                end
            end

            addr_start  <= (~state | (curr_reg === max_reg & (~widen | turn))) & en;
            addr_end    <= ((vlmul[2] | vlmul === 'b0) & en & ~widen) | (state & ((curr_reg === (max_reg-1) & ~widen) | (curr_reg === max_reg & widen)));
        end
    end

    // STATE MACHINE :)
    always @(posedge clk) begin
        case (state)
            1'b0: state <= rst_n & en; // IDLE
            1'b1: state <= rst_n & ((curr_reg !== max_reg & (~widen | turn)) | en); // BUSY
            default : state <= 1'b0;
        endcase
    end

endmodule