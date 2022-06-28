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
    output                      idle      // signal to processor that we can get another address
);

    reg [ADDR_WIDTH-1:0] curr_reg;
    reg [ADDR_WIDTH-1:0] max_reg;
    reg state;  // STATES: IDLE, BUSY

//   assign reg_group = (vlmul > 3'b000 && vlmul[2] === 1'b0);
    assign addr_out         = curr_reg;
    assign idle_single_addr = (vlmul[2] && ~en);
    assign idle             = ~state;

    // latching input values
    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            curr_reg <= 0;
            max_reg <= 0;
        end else begin
            if (state == 1'b0) begin
                if (en) begin
                    // curr_reg <= (vlmul[2] === 1'b0) ? addr_in << vlmul : addr_in;
                    curr_reg <= addr_in;
                    // max_reg <= (vlmul[2] === 1'b0) ? (addr_in << vlmul) + (1'b1 << vlmul) - 1'b1 : addr_in;
                    max_reg <= (vlmul[2] === 1'b0) ? addr_in + (1'b1 << vlmul) - 1'b1 : addr_in; 
                end
            end else begin
                if (curr_reg === max_reg) begin
                    if (en) begin
                        // curr_reg <= (vlmul[2] === 1'b0) ? addr_in << vlmul : addr_in;
                        // max_reg <= (vlmul[2] === 1'b0) ? (addr_in << vlmul) + (1'b1 << vlmul) - 1'b1 : addr_in;
                        curr_reg <= addr_in;
                        max_reg <= (vlmul[2] === 1'b0) ? addr_in + (1'b1 << vlmul) - 1'b1 : addr_in; 
                    end
                end else begin
                    curr_reg <= curr_reg + 1;
                end
            end
        end
    end

    // STATE MACHINE :)
    always @(posedge clk) begin
        case (state)
            1'b0: state <= rst_n & en; // IDLE
            1'b1: state <= rst_n & (curr_reg !== max_reg) | en; // BUSY
            default : state <= 1'b0;
        endcase
    end

endmodule