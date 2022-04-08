module mask_regfile #(
    parameter VLEN          = 256,      // bit length of a vector
    parameter VLEN_B        = VLEN/8    // byte length (mask length)
    parameter ADDR_WIDTH    = 5,        // this gives us 32 vectors
    parameter DATA_WIDTH    = 64,       // this is one vector width -- fine for access from vector accel. not fine from mem (will need aux interface)
    parameter PORTS         = 3,        // number of data ports
    parameter DW_B          = DATA_WIDTH/8,   // DATA_WIDTH in bytes
    parameter NUM_VECS      = (1 << ADDR_WIDTH)
) (
    // no data reset needed, if the user picks an unused register they get garbage data and that's their problem ¯\_(ツ)_/¯
    input                           clk,
    input                           rst_n,
    input                           en      [0:PORTS-1],    // no action unless high
    input                           ld_en,
    input                           st_en,
    input                           rw      [0:PORTS-1],    // 0 == read, 1 == write -- change this to separate read and write
    input       [ADDR_WIDTH-1:0]    addr    [0:PORTS-1],    // 32 possible vector registers -- TODO: would like to make this SP eventually!
    input       [ADDR_WIDTH-1:0]    ld_addr,
    input       [ADDR_WIDTH-1:0]    st_addr,
    input       [      DW_B-1:0]    data_in [0:PORTS-1],    // write 8 mask bits at a time
    input       [      DW_B-1:0]    ld_data_in,
    output reg  [      DW_B-1:0]    st_data_out,
    output reg  [      DW_B-1:0]    data_out[0:PORTS-1]     // read 8 mask bits at a time
);

    parameter MAX_IDX   = VLEN_B/DW_B - 1;
    parameter IDX_BITS  = $clog2(MAX_IDX + 1); // screw it I can't do the math rn

    logic [  IDX_BITS-1:0] curr_idx     [0:PORTS-1];
    logic [ADDR_WIDTH-1:0] curr_reg     [0:PORTS-1]; // latch current register just in case input changes!

    logic [  IDX_BITS-1:0] ld_curr_idx;
    logic [ADDR_WIDTH-1:0] ld_curr_reg;

    logic [  IDX_BITS-1:0] st_curr_idx;
    logic [ADDR_WIDTH-1:0] st_curr_reg;

    logic [ADDR_WIDTH-1:0] rw_reg       [0:PORTS-1];
    logic [ADDR_WIDTH-1:0] ld_reg;
    logic [ADDR_WIDTH-1:0] st_reg;

    logic [ADDR_WIDTH-1:0] rw_reg_2;

    logic [ADDR_WIDTH-1:0] data_start   [0:PORTS-1];
    logic [ADDR_WIDTH-1:0] data_end     [0:PORTS-1];

    // TODO: add request queue (using num_elems and busy flag) so we don't have to wait on requests to return always

    // TODO: change to a byte-addressable space, for strided reads.
    logic [VLEN_B/DW_B-1:0][DW_B-1:0] mask_data [0:NUM_VECS-1];

    logic [1:0] state [PORTS-1:0];  // STATES: IDLE, BUSY_R, BUSY_W
    logic ld_state;
    logic st_state;

    // --------------------------- DEBUG SIGNALS ------------------------------------
    logic [1:0] state_0;
    logic [1:0] state_1;
    logic [1:0] state_2;

    logic [DW_B-1:0] en_0;
    logic [DW_B-1:0] en_1;
    logic [DW_B-1:0] en_2;

    logic rw_0;
    logic rw_1;
    logic rw_2;

    logic [5:0] please;

    logic [VLEN_B/DW_B - 1:0][DW_B-1:0] mask_data_0;
    logic [VLEN_B/DW_B - 1:0][DW_B-1:0] mask_data_1;
    logic [VLEN_B/DW_B - 1:0][DW_B-1:0] mask_data_2;
    logic [VLEN_B/DW_B - 1:0][DW_B-1:0] mask_data_3;
    logic [VLEN_B/DW_B - 1:0][DW_B-1:0] mask_data_4;
    logic [VLEN_B/DW_B - 1:0][DW_B-1:0] mask_data_5;
    logic [VLEN_B/DW_B - 1:0][DW_B-1:0] mask_data_6;
    logic [VLEN_B/DW_B - 1:0][DW_B-1:0] mask_data_7;
    logic [VLEN_B/DW_B - 1:0][DW_B-1:0] mask_data_8;
    logic [VLEN_B/DW_B - 1:0][DW_B-1:0] mask_data_9;
    logic [VLEN_B/DW_B - 1:0][DW_B-1:0] mask_data_10;
    logic [VLEN_B/DW_B - 1:0][DW_B-1:0] mask_data_11;
    logic [VLEN_B/DW_B - 1:0][DW_B-1:0] mask_data_12;
    logic [VLEN_B/DW_B - 1:0][DW_B-1:0] mask_data_13;
    logic [VLEN_B/DW_B - 1:0][DW_B-1:0] mask_data_14;
    logic [VLEN_B/DW_B - 1:0][DW_B-1:0] mask_data_15;
    logic [VLEN_B/DW_B - 1:0][DW_B-1:0] mask_data_16;
    logic [VLEN_B/DW_B - 1:0][DW_B-1:0] mask_data_17;
    logic [VLEN_B/DW_B - 1:0][DW_B-1:0] mask_data_18;
    logic [VLEN_B/DW_B - 1:0][DW_B-1:0] mask_data_19;
    logic [VLEN_B/DW_B - 1:0][DW_B-1:0] mask_data_20;
    logic [VLEN_B/DW_B - 1:0][DW_B-1:0] mask_data_21;
    logic [VLEN_B/DW_B - 1:0][DW_B-1:0] mask_data_22;
    logic [VLEN_B/DW_B - 1:0][DW_B-1:0] mask_data_23;
    logic [VLEN_B/DW_B - 1:0][DW_B-1:0] mask_data_24;
    logic [VLEN_B/DW_B - 1:0][DW_B-1:0] mask_data_25;
    logic [VLEN_B/DW_B - 1:0][DW_B-1:0] mask_data_26;
    logic [VLEN_B/DW_B - 1:0][DW_B-1:0] mask_data_27;
    logic [VLEN_B/DW_B - 1:0][DW_B-1:0] mask_data_28;
    logic [VLEN_B/DW_B - 1:0][DW_B-1:0] mask_data_29;
    logic [VLEN_B/DW_B - 1:0][DW_B-1:0] mask_data_30;
    logic [VLEN_B/DW_B - 1:0][DW_B-1:0] mask_data_31;

    logic [IDX_BITS - 1:0] curr_idx_0;
    logic [IDX_BITS - 1:0] curr_idx_1;
    logic [IDX_BITS - 1:0] curr_idx_2;

    logic [ADDR_WIDTH-1:0] curr_reg_0;
    logic [ADDR_WIDTH-1:0] curr_reg_1;
    logic [ADDR_WIDTH-1:0] curr_reg_2;

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

    assign mask_data_0  = mask_data[0];
    assign mask_data_1  = mask_data[1];
    assign mask_data_2  = mask_data[2];
    assign mask_data_3  = mask_data[3];
    assign mask_data_4  = mask_data[4];
    assign mask_data_5  = mask_data[5];
    assign mask_data_6  = mask_data[6];
    assign mask_data_7  = mask_data[7];
    assign mask_data_8  = mask_data[8];
    assign mask_data_9  = mask_data[9];
    assign mask_data_10 = mask_data[10];
    assign mask_data_11 = mask_data[11];
    assign mask_data_12 = mask_data[12];
    assign mask_data_13 = mask_data[13];
    assign mask_data_14 = mask_data[14];
    assign mask_data_15 = mask_data[15];
    assign mask_data_16 = mask_data[16];
    assign mask_data_17 = mask_data[17];
    assign mask_data_18 = mask_data[18];
    assign mask_data_19 = mask_data[19];
    assign mask_data_20 = mask_data[20];
    assign mask_data_21 = mask_data[21];
    assign mask_data_22 = mask_data[22];
    assign mask_data_23 = mask_data[23];
    assign mask_data_24 = mask_data[24];
    assign mask_data_25 = mask_data[25];
    assign mask_data_26 = mask_data[26];
    assign mask_data_27 = mask_data[27];
    assign mask_data_28 = mask_data[28];
    assign mask_data_29 = mask_data[29];
    assign mask_data_30 = mask_data[30];
    assign mask_data_31 = mask_data[31];

    // TODO: continuous register data
//     assign data_start = curr_reg + curr_idx;

    // TODO: make this hardcoded 2 read 1 write i guess

    // ----------------------------- REGISTER INIT --------------------------------------
    genvar i;
    genvar j;

    generate
        initial begin
            for (int c = 0; c < 4; c++) begin
                for (int d = 0; d < MAX_IDX + 1; d++) begin
                    mask_data[c][d] <= {DB_B{1'b1}};
                end
            end
        end
    endgenerate

    // --------------------------- REGISTER TRACKING ------------------------------------
    generate
        for (i = 0; i < PORTS; i++) begin
            always @(posedge clk or negedge rst_n) begin
                curr_reg[i] <= {ADDR_WIDTH{rst_n}} & ((|en[i] && state[i] == 2'b00) ? addr[i] : curr_reg[i]);

                case(state[i])
                    2'b00:  curr_idx[i] <= (rst_n & |en[i] & (MAX_IDX > 0)); // If any enable bits are high, we should update
                    2'b01,
                    2'b10:  curr_idx[i] <= (~rst_n || curr_idx[i] == MAX_IDX) ? 0 : curr_idx[i] + 1;
                    default: curr_idx[i] <= 0;
                endcase
            end
        end
    endgenerate

    // MEMORY PORT VERISONS -- LOAD
    always @(posedge clk or negedge rst_n) begin
        ld_curr_reg <= {ADDR_WIDTH{rst_n}} & ((|ld_en && ld_state == 1'b0) ? ld_addr : ld_curr_reg);

        case(ld_state)
            1'b0:   ld_curr_idx <= (rst_n & |ld_en & (MAX_IDX > 0)); // If any enable bits are high, we should update
            1'b1:   ld_curr_idx <= (~rst_n || ld_curr_idx == MAX_IDX) ? 0 : ld_curr_idx + 1;
        endcase
    end

    // MEMORY PORT VERISONS -- STORE
    always @(posedge clk or negedge rst_n) begin
        st_curr_reg <= {ADDR_WIDTH{rst_n}} & ((|st_en && st_state == 1'b0) ? st_addr : st_curr_reg);

        case(st_state)
            1'b0:   st_curr_idx <= (rst_n & |st_en & (MAX_IDX > 0)); // If any enable bits are high, we should update
            1'b1:   st_curr_idx <= (~rst_n || st_curr_idx == MAX_IDX) ? 0 : st_curr_idx + 1;
        endcase
    end

    // TODO: implement multi-cycle read/write more like this somehow
//   assign data_start = curr_idx*VLEN;
//   assign data_end = data_start + VLEN - 1;

    // --------------------------- READING AND WRITING ------------------------------------
    generate
        for (i = 0; i < PORTS; i++) begin
            assign rw_reg[i] = (MAX_IDX > 0 && curr_idx[i] >= 0) ? curr_reg[i] : addr[i];
            always @(posedge clk) begin
                if (~rst_n) begin
                    data_out[i] <= {DW_B{1'b1}};    // reset to all high
                end else begin
                    if (en[i][j] && ~rw[i] || state[i] == 2'b01) begin // read
                        data_out[i] <= mask_data[rw_reg[i]][curr_idx[i]];
                    end else if (en[i] && rw[i] || state[i] == 2'b10) begin
                        mask_data[rw_reg[i]][curr_idx[i]] <= data_in[i];
                    end
                end
            end
        end

        // LOAD WRITING AND STORE READING
        assign ld_reg = (MAX_IDX > 0 && ld_curr_idx >= 0) ? ld_curr_reg : ld_addr;
        assign st_reg = (MAX_IDX > 0 && st_curr_idx >= 0) ? st_curr_reg : st_addr;

        always @(posedge clk) begin
            if (rst_n & (st_en | st_state)) begin
                st_data_out <= mask_data[st_reg][st_curr_idx];
            end

            if (rst_n & (ld_en | ld_state)) begin
                mask_data[ld_reg][ld_curr_idx] <= ld_data_in;
            end
        end
    endgenerate


    // --------------------------- STATE MACHINES :) ---------------------------------------
    generate
        for (i = 0; i < PORTS; i++) begin
            always @(posedge clk) begin
                if (MAX_IDX > 0) begin
                    case (state[i])
                        2'b00: state[i] <= {2{(rst_n & |en[i])}} & (rw[i] ? 2'b10 : 2'b01); // IDLE
                        2'b01, // BUSY_RD
                            2'b10: state[i] <= {2{rst_n & (curr_idx[i] != MAX_IDX)}} & state[i]; // BUSY
                        default : state[i] <= 2'b00;
                    endcase
                end else begin
                    state[i] <= 2'b00;
                end
            end
        end
    endgenerate

    always @(posedge clk) begin
        if (MAX_IDX > 0) begin
            case (ld_state)
                1'b0:   ld_state <= rst_n & |ld_en; // IDLE
                1'b1:   ld_state <= rst_n & (ld_curr_idx != MAX_IDX) & ld_state; // BUSY
                default: ld_state <= 1'b0;
            endcase
        end else begin
            ld_state <= 2'b0;
        end
    end

    always @(posedge clk) begin
        if (MAX_IDX > 0) begin
            case (st_state)
                1'b0:   st_state <= rst_n & |st_en; // IDLE
                1'b1:   st_state <= rst_n & (st_curr_idx != MAX_IDX) & st_state; // BUSY
                default: st_state <= 1'b0;
            endcase
        end else begin
            st_state <= 2'b0;
        end
    end

endmodule
