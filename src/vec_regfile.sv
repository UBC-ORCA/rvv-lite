module vec_regfile #(
    parameter VLEN = 256,           // bit length of a vector
    parameter ADDR_WIDTH = 5,       // this gives us 32 vectors
    parameter DATA_WIDTH,           // this is one vector width -- fine for access from vector accel. not fine from mem (will need aux interface)
    parameter PORTS = 3,            // number of data ports
    parameter DW_B = DATA_WIDTH/8,   // DATA_WIDTH in bytes
    parameter NUM_VECS = (1 << ADDR_WIDTH)
) (
    // no data reset needed, if the user picks an unused register they get garbage data and that's their problem ¯\_(ツ)_/¯
    input clk,
    input rst,
    input [DW_B-1:0] en [0:PORTS-1],    // no action unless high
    input rw [0:PORTS-1],               // 0 == read, 1 == write
    input [ADDR_WIDTH-1:0] addr [0:PORTS-1],    // 32 possible vector registers -- TODO: would like to make this SP eventually!
    input [DATA_WIDTH-1:0] data_in [0:PORTS-1],     // write 64 bits at a time
    // input [7:0] num_elems, // we can know this from vsetvli
    output reg [DATA_WIDTH-1:0] data_out [0:PORTS-1]  // read 64 bits at a time
);

    parameter MAX_IDX = VLEN/DATA_WIDTH - 1;
    parameter IDX_BITS = $clog2(MAX_IDX + 1); // screw it I can't do the math rn

    reg [IDX_BITS - 1:0] curr_idx [0:PORTS-1];
    reg [ADDR_WIDTH-1:0] curr_reg [0:PORTS-1]; // latch current register just in case input changes!

    wire [ADDR_WIDTH-1:0] rw_reg [0:PORTS-1];

    wire [ADDR_WIDTH-1:0] rw_reg_2;

    wire [ADDR_WIDTH-1:0] data_start[0:PORTS-1];
    wire [ADDR_WIDTH-1:0] data_end[0:PORTS-1];

    reg [DATA_WIDTH-1:0] data_tmp [0:PORTS-1];

    // TODO: add request queue (using num_elems and busy flag) so we don't have to wait on requests to return always

    // TODO: change to a byte-addressable space, for strided reads.
    reg [VLEN/DATA_WIDTH - 1:0][DATA_WIDTH-1:0] vec_data [0:NUM_VECS-1];
//      reg [(VLEN/DATA_WIDTH)-1:0][DW_B-1:0][8-1:0] vec_data [ADDR_WIDTH-1:0];
//   reg [DATA_WIDTH-1:0] vec_data;
//   reg [ADDR_WIDTH-1:0] vec_data [VLEN-1:0];

    reg [1:0] state [PORTS-1:0];  // STATES: IDLE, BUSY_R, BUSY_W

    // --------------------------- DEBUG SIGNALS ------------------------------------
    wire [1:0] state_0;
    wire [1:0] state_1;
    wire [1:0] state_2;

    wire [DW_B-1:0] en_0;
    wire [DW_B-1:0] en_1;
    wire [DW_B-1:0] en_2;

    wire rw_0;
    wire rw_1;
    wire rw_2;

    wire [5:0] please;

    wire [VLEN/DATA_WIDTH - 1:0][DATA_WIDTH-1:0] vec_data_0;
    wire [VLEN/DATA_WIDTH - 1:0][DATA_WIDTH-1:0] vec_data_1;
    wire [VLEN/DATA_WIDTH - 1:0][DATA_WIDTH-1:0] vec_data_2;
    wire [VLEN/DATA_WIDTH - 1:0][DATA_WIDTH-1:0] vec_data_3;
    wire [VLEN/DATA_WIDTH - 1:0][DATA_WIDTH-1:0] vec_data_4;
    wire [VLEN/DATA_WIDTH - 1:0][DATA_WIDTH-1:0] vec_data_5;
    wire [VLEN/DATA_WIDTH - 1:0][DATA_WIDTH-1:0] vec_data_6;

    wire [IDX_BITS - 1:0] curr_idx_0;
    wire [IDX_BITS - 1:0] curr_idx_1;
    wire [IDX_BITS - 1:0] curr_idx_2;

    wire [ADDR_WIDTH-1:0] curr_reg_0;
    wire [ADDR_WIDTH-1:0] curr_reg_1;
    wire [ADDR_WIDTH-1:0] curr_reg_2;

    assign curr_idx_0 = curr_idx[0];
    assign curr_idx_1 = curr_idx[1];
    assign curr_idx_2 = curr_idx[2];

    assign curr_reg_0 = curr_reg[0];
    assign curr_reg_1 = curr_reg[1];
    assign curr_reg_2 = curr_reg[2];

    assign rw_reg_2 = rw_reg[2];

    assign state_0 = state[0];
    assign state_1 = state[1];
    assign state_2 = state[2];

    assign en_0 = en[0];
    assign en_1 = en[1];
    assign en_2 = en[2];

    assign rw_0 = rw[0];
    assign rw_1 = rw[1];
    assign rw_2 = rw[2];

    assign vec_data_0 = vec_data[0];
    assign vec_data_1 = vec_data[1];
    assign vec_data_2 = vec_data[2];
    assign vec_data_3 = vec_data[3];
    assign vec_data_4 = vec_data[4];
    assign vec_data_5 = vec_data[5];
    assign vec_data_6 = vec_data[6];

    // TODO: continuous register data
//     assign data_start = curr_reg + curr_idx;

    // ----------------------------- REGISTER INIT --------------------------------------
    genvar i;
    genvar j;

    generate
        for (j = 0; j < DW_B; j++) begin
            initial begin
                for (int c = 0; c < 4; c++) begin
                    for (int d = 0; d < MAX_IDX + 1; d++) begin
                        vec_data[c][d][(j+1)*8-1:j*8] <= c;
                    end
                end
            end
        end
    endgenerate

    // --------------------------- REGISTER TRACKING ------------------------------------
    generate
        // latching input https://www.edaplayground.com/x/c_t8#design0values
        for (i = 0; i < PORTS; i++) begin
            always @(posedge clk or negedge rst) begin
                if (~rst) begin
                    curr_idx[i] <= 0;
                    curr_reg[i] <= 0;
                end else begin
                    if (en[i][0]) begin
                        if (state[i] == 2'b00) begin
                            curr_reg[i] <= addr[i];
                            curr_idx[i] <= (MAX_IDX > 0) ? 1 : 0;
                        end
                    end else begin
                        curr_idx[i] <= 0;
                    end

                    if (state[i] == 2'b01 || state[i] == 2'b10) begin // if state is 01 or 10 :)
                        curr_idx[i] <= (curr_idx[i] == MAX_IDX) ? 0 : curr_idx[i] + 1;
                    end
                end
            end
        end
    endgenerate

    // TODO: implement multi-cycle read/write more like this somehow
//   assign data_start = curr_idx*VLEN;
//   assign data_end = data_start + VLEN - 1;

    // --------------------------- READING AND WRITING ------------------------------------
    generate
        for (i = 0; i < PORTS; i++) begin
            assign rw_reg[i] = (MAX_IDX > 0 && curr_idx[i] >= 0) ? curr_reg[i] : addr[i];
            for (j = 0; j < DW_B; j++) begin
                always @(posedge clk) begin
                    if (~rst) begin
                        data_out[i][(j+1)*8-1:j*8] <= 8'h0;
                    end else begin
                        if (en[i][j] && ~rw[i] || state[i] == 2'b01) begin // read
                            data_out[i][(j+1)*8-1:j*8] <= vec_data[rw_reg[i]][curr_idx[i]][(j+1)*8-1:j*8];
                        end else if (en[i][j] && rw[i] || state[i] == 2'b10) begin
                            vec_data[rw_reg[i]][curr_idx[i]][(j+1)*8-1:j*8] <= data_in[i][(j+1)*8-1:j*8];
                        end else begin
                        end
                    end
                end
            end
            //         end
        end
    endgenerate


    // --------------------------- STATE MACHINE :) ---------------------------------------
    generate
        for (i = 0; i < PORTS; i++) begin
            always @(posedge clk) begin
                if (MAX_IDX > 0) begin
                    if (~rst) begin
                        state[i] <= 2'b00;
                    end else begin
                        case (state[i])
                            2'b00: begin
                                if (en[i][0]) begin
                                    state[i] <= (rw[i] ? 2'b10 : 2'b01);
                                end
                            end // IDLE
                            2'b01, // BUSY_RD
                                2'b10: begin
                                    state[i] <= (curr_idx[i] == MAX_IDX) ? 2'b00 : state[i];
                                end // BUSY_WR
                            default : state[i] <= 2'b00;
                        endcase
                    end
                end else begin
                    state[i] <= 2'b00;
                end
            end
        end
    endgenerate

endmodule
