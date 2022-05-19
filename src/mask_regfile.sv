module mask_regfile #(
    parameter VLEN          = 256,      // bit length of a vector
    parameter VLEN_B        = VLEN/8,   // byte length (mask length)
    parameter ADDR_WIDTH    = 5,        // this gives us 32 vectors
    parameter DATA_WIDTH    = 64,       // this is one vector width -- fine for access from vector accel. not fine from mem (will need aux interface)
    parameter PORTS         = 3,        // number of data ports
    parameter DW_B          = DATA_WIDTH/8,   // DATA_WIDTH in bytes
    parameter NUM_VECS      = (1 << ADDR_WIDTH)
) (
    // no data reset needed, if the user picks an unused register they get garbage data and that's their problem ¯\_(ツ)_/¯
    input                           clk,
    input                           rst_n,
    input       [      DW_B-1:0]    rd_en_1,
    input       [      DW_B-1:0]    rd_en_2,
    input       [      DW_B-1:0]    wr_en,
    input       [      DW_B-1:0]    ld_en,
    input       [      DW_B-1:0]    st_en,
    input       [ADDR_WIDTH-1:0]    rd_addr_1,
    input       [ADDR_WIDTH-1:0]    rd_addr_2,
    input       [ADDR_WIDTH-1:0]    wr_addr,
    input       [ADDR_WIDTH-1:0]    ld_addr,
    input       [ADDR_WIDTH-1:0]    st_addr,
    input       [DATA_WIDTH-1:0]    wr_data_in, // write 64 bits at a time
    input       [DATA_WIDTH-1:0]    ld_data_in,
    // input [7:0] num_elems, // we can know this from vsetvli
    output reg  [DATA_WIDTH-1:0]    st_data_out,
    output reg  [DATA_WIDTH-1:0]    rd_data_out_1, // read 64 bits at a time
    output reg  [DATA_WIDTH-1:0]    rd_data_out_2 
);

    parameter MAX_IDX   = VLEN_B/DW_B - 1;
    parameter IDX_BITS  = ($clog2(MAX_IDX + 1) > 0) ? $clog2(MAX_IDX + 1) : 1; // screw it I can't do the math rn

    reg [  IDX_BITS-1:0] rd_curr_idx_1;
    reg [  IDX_BITS-1:0] rd_curr_idx_2; 
    reg [  IDX_BITS-1:0] wr_curr_idx;
    reg [  IDX_BITS-1:0] ld_curr_idx;
    reg [  IDX_BITS-1:0] st_curr_idx;

    // latch current register just in case input changes!
    reg [ADDR_WIDTH-1:0] rd_curr_reg_1;
    reg [ADDR_WIDTH-1:0] rd_curr_reg_2;
    reg [ADDR_WIDTH-1:0] wr_curr_reg;
    reg [ADDR_WIDTH-1:0] ld_curr_reg;
    reg [ADDR_WIDTH-1:0] st_curr_reg;

    wire [ADDR_WIDTH-1:0] rd_reg_1;
    wire [ADDR_WIDTH-1:0] rd_reg_2;
    wire [ADDR_WIDTH-1:0] wr_reg; 
    wire [ADDR_WIDTH-1:0] ld_reg;
    wire [ADDR_WIDTH-1:0] st_reg;

    // TODO: add request queue (using num_elems and busy flag) so we don't have to wait on requests to return always

    // TODO: change to a byte-addressable space, for strided reads.
    reg [     VLEN_B-1:0] mask_data [0:NUM_VECS-1];

    // STATES: IDLE, BUSY
    reg                   rd_state_1;
    reg                   rd_state_2;
    reg                   wr_state;
    reg                   ld_state;
    reg                   st_state;

    // This better work lmfao
    wire [       DW_B-1:0] wr_conflict;

    // --------------------------- DEBUG SIGNALS ------------------------------------
    wire  [    VLEN_B-1:0] mask_data_0;
    wire  [    VLEN_B-1:0] mask_data_1;
    wire  [    VLEN_B-1:0] mask_data_2;
    wire  [    VLEN_B-1:0] mask_data_3;
    wire  [    VLEN_B-1:0] mask_data_4;
    wire  [    VLEN_B-1:0] mask_data_5;
    wire  [    VLEN_B-1:0] mask_data_6;
    wire  [    VLEN_B-1:0] mask_data_7;
    wire  [    VLEN_B-1:0] mask_data_8;
    wire  [    VLEN_B-1:0] mask_data_9;
    wire  [    VLEN_B-1:0] mask_data_10;
    wire  [    VLEN_B-1:0] mask_data_11;
    wire  [    VLEN_B-1:0] mask_data_12;
    wire  [    VLEN_B-1:0] mask_data_13;
    wire  [    VLEN_B-1:0] mask_data_14;
    wire  [    VLEN_B-1:0] mask_data_15;
    wire  [    VLEN_B-1:0] mask_data_16;
    wire  [    VLEN_B-1:0] mask_data_17;
    wire  [    VLEN_B-1:0] mask_data_18;
    wire  [    VLEN_B-1:0] mask_data_19;
    wire  [    VLEN_B-1:0] mask_data_20;
    wire  [    VLEN_B-1:0] mask_data_21;
    wire  [    VLEN_B-1:0] mask_data_22;
    wire  [    VLEN_B-1:0] mask_data_23;
    wire  [    VLEN_B-1:0] mask_data_24;
    wire  [    VLEN_B-1:0] mask_data_25;
    wire  [    VLEN_B-1:0] mask_data_26;
    wire  [    VLEN_B-1:0] mask_data_27;
    wire  [    VLEN_B-1:0] mask_data_28;
    wire  [    VLEN_B-1:0] mask_data_29;
    wire  [    VLEN_B-1:0] mask_data_30;
    wire  [    VLEN_B-1:0] mask_data_31;

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

    integer c, d;

    generate
        initial begin
            for (c = 0; c < NUM_VECS; c=c+1) begin
                mask_data[c] = {DW_B{1'b1}};
            end
        end
    endgenerate

    // --------------------------- REGISTER TRACKING ------------------------------------
    // READ PORTS
    always @(posedge clk) begin
        rd_curr_reg_1 <= {ADDR_WIDTH{rst_n}} & ((|rd_en_1 && rd_state_1 == 1'b0) ? rd_addr_1 : rd_curr_reg_1);

        case(rd_state_1)
            1'b0:   rd_curr_idx_1 <= (rst_n & |rd_en_1 & (MAX_IDX > 0)); // If any enable bits are high, we should update
            1'b1:   rd_curr_idx_1 <= (~rst_n || rd_curr_idx_1 == MAX_IDX) ? 0 : rd_curr_idx_1 + 1;
        endcase
    end

    always @(posedge clk) begin
        rd_curr_reg_2 <= {ADDR_WIDTH{rst_n}} & ((|rd_en_2 && rd_state_2 == 1'b0) ? rd_addr_2 : rd_curr_reg_2);

        case(rd_state_2)
            1'b0:   rd_curr_idx_2 <= (rst_n & |rd_en_2 & (MAX_IDX > 0)); // If any enable bits are high, we should update
            1'b1:   rd_curr_idx_2 <= (~rst_n || rd_curr_idx_2 == MAX_IDX) ? 0 : rd_curr_idx_2 + 1;
        endcase
    end

    // WRITE PORTS
    always @(posedge clk) begin
        wr_curr_reg <= {ADDR_WIDTH{rst_n}} & ((|wr_en && wr_state == 1'b0) ? wr_addr : wr_curr_reg);

        case(ld_state)
            1'b0:   wr_curr_idx <= (rst_n & |wr_en & (MAX_IDX > 0)); // If any enable bits are high, we should update
            1'b1:   wr_curr_idx <= (~rst_n || wr_curr_idx == MAX_IDX) ? 0 : wr_curr_idx + 1;
        endcase
    end

    // MEMORY PORT VERISONS -- LOAD
    always @(posedge clk) begin
        ld_curr_reg <= {ADDR_WIDTH{rst_n}} & ((|ld_en && ld_state == 1'b0) ? ld_addr : ld_curr_reg);

        case(ld_state)
            1'b0:   ld_curr_idx <= (rst_n & |ld_en & (MAX_IDX > 0)); // If any enable bits are high, we should update
            1'b1:   ld_curr_idx <= (~rst_n || ld_curr_idx == MAX_IDX) ? 0 : ld_curr_idx + 1;
        endcase
    end

    // MEMORY PORT VERISONS -- STORE
    always @(posedge clk) begin
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
        // WHICH REG DO WE READ FROM NOW
        // ALU PORTS
        assign rd_reg_1 = (MAX_IDX > 0 && rd_curr_idx_1 >= 0) ? rd_curr_reg_1 : rd_addr_1;
        assign rd_reg_2 = (MAX_IDX > 0 && rd_curr_idx_2 >= 0) ? rd_curr_reg_2 : rd_addr_2;
        assign wr_reg   = (MAX_IDX > 0 && wr_curr_idx   >= 0) ? wr_curr_reg : wr_addr;

        // MEM PORTS
        assign ld_reg   = (MAX_IDX > 0 && ld_curr_idx >= 0) ? ld_curr_reg : ld_addr;
        assign st_reg   = (MAX_IDX > 0 && st_curr_idx >= 0) ? st_curr_reg : st_addr;

        // assign rd_mem_idx_1 =   rd_reg_1*DW_B   + rd_curr_idx_1;
        // assign rd_mem_idx_2 =   rd_reg_2*DW_B   + rd_curr_idx_2;
        // assign wr_mem_idx   =   wr_reg*DW_B     + wr_curr_idx;

        // assign ld_mem_idx   =   ld_reg*DW_B + ld_curr_idx;
        // assign st_mem_idx   =   st_reg*DW_B + st_curr_idx;

        for (j = 0; j < DW_B; j=j+1) begin
            assign wr_conflict[j] = (wr_reg === ld_reg) && ((wr_en[j] | wr_state) & ((ld_en[j] | ld_state)));

            always @(posedge clk) begin
                if (rst_n & (rd_en_1[j] | rd_state_1)) begin
                    rd_data_out_1[j]    <= mask_data[rd_reg_1][j];
                end
                if (rst_n & (rd_en_2[j] | rd_state_2)) begin
                    rd_data_out_2[j]    <= mask_data[rd_reg_2][j];
                end

                if (rst_n & ((wr_en[j] | wr_state) | (ld_en[j] | ld_state))) begin
                    if (wr_conflict[j]) begin
                        mask_data[wr_reg][j] <= wr_data_in[j];
                    end else begin
                        if (wr_en[j] | wr_state) begin
                            mask_data[wr_reg][j] <= wr_data_in[j];
                        end
                        if (ld_en[j] | ld_state) begin
                            mask_data[ld_reg][j] <= ld_data_in[j];
                        end 
                    end
                end

                if (rst_n & (st_en[j] | st_state)) begin
                    st_data_out[j]  <= mask_data[st_reg][j];
                end
            end
        end
    endgenerate


    // --------------------------- STATE MACHINES :) ---------------------------------------
    // ALU PORT STATES
    always @(posedge clk) begin
        if (MAX_IDX > 0) begin
            case (rd_state_1)
                1'b0:       rd_state_1  <= rst_n & |rd_en_1; // IDLE
                1'b1:       rd_state_1  <= rst_n & (rd_curr_idx_1 != MAX_IDX) & rd_state_1; // BUSY
                default:    rd_state_1  <= 1'b0;
            endcase
        end else begin
            rd_state_1  <= 2'b0;
        end
    end

    always @(posedge clk) begin
        if (MAX_IDX > 0) begin
            case (rd_state_2)
                1'b0:       rd_state_2  <= rst_n & |rd_en_2; // IDLE
                1'b1:       rd_state_2  <= rst_n & (rd_curr_idx_2 != MAX_IDX) & rd_state_2; // BUSY
                default:    rd_state_2  <= 1'b0;
            endcase
        end else begin
            rd_state_2  <= 2'b0;
        end
    end

    always @(posedge clk) begin
        if (MAX_IDX > 0) begin
            case (wr_state)
                1'b0:       wr_state    <= rst_n & |wr_en; // IDLE
                1'b1:       wr_state    <= rst_n & (wr_curr_idx != MAX_IDX) & wr_state; // BUSY
                default:    wr_state    <= 1'b0;
            endcase
        end else begin
            wr_state    <= 2'b0;
        end
    end

    // MEM PORT STATES
    always @(posedge clk) begin
        if (MAX_IDX > 0) begin
            case (ld_state)
                1'b0:       ld_state    <= rst_n & |ld_en; // IDLE
                1'b1:       ld_state    <= rst_n & (ld_curr_idx != MAX_IDX) & ld_state; // BUSY
                default:    ld_state    <= 1'b0;
            endcase
        end else begin
            ld_state    <= 2'b0;
        end
    end

    always @(posedge clk) begin
        if (MAX_IDX > 0) begin
            case (st_state)
                1'b0:       st_state    <= rst_n & |st_en; // IDLE
                1'b1:       st_state    <= rst_n & (st_curr_idx != MAX_IDX) & st_state; // BUSY
                default:    st_state    <= 1'b0;
            endcase
        end else begin
            st_state    <= 2'b0;
        end
    end

endmodule
