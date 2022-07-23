module mask_regfile #(
    parameter VLEN          = 256,      // bit length of a vector
    parameter VLEN_B        = VLEN/8,   // byte length (mask length)
    parameter ADDR_WIDTH    = 5,        // this gives us 32 vectors
    parameter DATA_WIDTH    = 64,       // this is one vector width -- fine for access from vector accel. not fine from mem (will need aux interface)
    parameter DW_B          = DATA_WIDTH/8, // DATA_WIDTH in bytes
    parameter OFF_BITS      = 8             // 2048/64 needs 8 bits
    )(
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
    input       [  OFF_BITS-1:0]    rd_off_1, // offsets (because data_width < vlen)
    input       [  OFF_BITS-1:0]    rd_off_2,
    input       [  OFF_BITS-1:0]    wr_off,
    input       [  OFF_BITS-1:0]    ld_off,
    input       [  OFF_BITS-1:0]    st_off,
    input       [DATA_WIDTH-1:0]    wr_data_in, // write 64 bits at a time
    input       [DATA_WIDTH-1:0]    ld_data_in,
    // input [7:0] num_elems, // we can know this from vsetvli
    output reg  [DATA_WIDTH-1:0]    st_data_out,
    output reg  [DATA_WIDTH-1:0]    rd_data_out_1, // read 64 bits at a time
    output reg  [DATA_WIDTH-1:0]    rd_data_out_2 
);

    // TODO: add request queue (using num_elems and busy flag) so we don't have to wait on requests to return always

    // TODO: change to a byte-addressable space, for strided reads?
    reg [(VLEN/DATA_WIDTH)-1:0][DW_B-1:0] mask_data [0:(1 << ADDR_WIDTH)-1];

    // STATES: IDLE, BUSY
    reg                   rd_state_1;
    reg                   rd_state_2;
    reg                   wr_state;
    reg                   ld_state;
    reg                   st_state;

    // --------------------------- DEBUG SIGNALS ------------------------------------
    // wire  [    VLEN_B-1:0] mask_data_0;
    // wire  [    VLEN_B-1:0] mask_data_1;
    // wire  [    VLEN_B-1:0] mask_data_2;
    // wire  [    VLEN_B-1:0] mask_data_3;
    // wire  [    VLEN_B-1:0] mask_data_4;
    // wire  [    VLEN_B-1:0] mask_data_5;
    // wire  [    VLEN_B-1:0] mask_data_6;
    // wire  [    VLEN_B-1:0] mask_data_7;
    // wire  [    VLEN_B-1:0] mask_data_8;
    // wire  [    VLEN_B-1:0] mask_data_9;
    // wire  [    VLEN_B-1:0] mask_data_10;
    // wire  [    VLEN_B-1:0] mask_data_11;
    // wire  [    VLEN_B-1:0] mask_data_12;
    // wire  [    VLEN_B-1:0] mask_data_13;
    // wire  [    VLEN_B-1:0] mask_data_14;
    // wire  [    VLEN_B-1:0] mask_data_15;
    // wire  [    VLEN_B-1:0] mask_data_16;
    // wire  [    VLEN_B-1:0] mask_data_17;
    // wire  [    VLEN_B-1:0] mask_data_18;
    // wire  [    VLEN_B-1:0] mask_data_19;
    // wire  [    VLEN_B-1:0] mask_data_20;
    // wire  [    VLEN_B-1:0] mask_data_21;
    // wire  [    VLEN_B-1:0] mask_data_22;
    // wire  [    VLEN_B-1:0] mask_data_23;
    // wire  [    VLEN_B-1:0] mask_data_24;
    // wire  [    VLEN_B-1:0] mask_data_25;
    // wire  [    VLEN_B-1:0] mask_data_26;
    // wire  [    VLEN_B-1:0] mask_data_27;
    // wire  [    VLEN_B-1:0] mask_data_28;
    // wire  [    VLEN_B-1:0] mask_data_29;
    // wire  [    VLEN_B-1:0] mask_data_30;
    // wire  [    VLEN_B-1:0] mask_data_31;

    // assign mask_data_0  = mask_data[0];
    // assign mask_data_1  = mask_data[1];
    // assign mask_data_2  = mask_data[2];
    // assign mask_data_3  = mask_data[3];
    // assign mask_data_4  = mask_data[4];
    // assign mask_data_5  = mask_data[5];
    // assign mask_data_6  = mask_data[6];
    // assign mask_data_7  = mask_data[7];
    // assign mask_data_8  = mask_data[8];
    // assign mask_data_9  = mask_data[9];
    // assign mask_data_10 = mask_data[10];
    // assign mask_data_11 = mask_data[11];
    // assign mask_data_12 = mask_data[12];
    // assign mask_data_13 = mask_data[13];
    // assign mask_data_14 = mask_data[14];
    // assign mask_data_15 = mask_data[15];
    // assign mask_data_16 = mask_data[16];
    // assign mask_data_17 = mask_data[17];
    // assign mask_data_18 = mask_data[18];
    // assign mask_data_19 = mask_data[19];
    // assign mask_data_20 = mask_data[20];
    // assign mask_data_21 = mask_data[21];
    // assign mask_data_22 = mask_data[22];
    // assign mask_data_23 = mask_data[23];
    // assign mask_data_24 = mask_data[24];
    // assign mask_data_25 = mask_data[25];
    // assign mask_data_26 = mask_data[26];
    // assign mask_data_27 = mask_data[27];
    // assign mask_data_28 = mask_data[28];
    // assign mask_data_29 = mask_data[29];
    // assign mask_data_30 = mask_data[30];
    // assign mask_data_31 = mask_data[31];

    // TODO: continuous register data
//     assign data_start = curr_addr + curr_idx;

    // TODO: make this hardcoded 2 read 1 write i guess

    // ----------------------------- REGISTER INIT --------------------------------------
    genvar i;
    genvar j;

    integer c, d;

    generate
        initial begin
            for (d = 0; d < (VLEN/DATA_WIDTH); d++) begin
                for (c = 0; c < (1 << ADDR_WIDTH); c=c+1) begin
                    mask_data[c][d] = {DW_B{1'b1}};
                end
            end
        end
    endgenerate

    // --------------------------- READING AND WRITING ------------------------------------
    generate
        assign wr_conflict = (wr_addr === ld_addr);

        for (j = 0; j < DW_B; j=j+1) begin
            always @(posedge clk) begin
                if (rd_en_1[j]) begin
                    rd_data_out_1[j]    <= {DW_B{rst_n}} & mask_data[rd_addr_1][rd_off_1][j];
                end
                if (rd_en_2[j]) begin
                    rd_data_out_2[j]    <= {DW_B{rst_n}} & mask_data[rd_addr_2][rd_off_2][j];
                end

                // Prioritize reg writeback over load writeback. Realistically we shouldn't have conflicts, this is just to be safe
                // FIXME
                if (wr_en[j]) begin
                    mask_data[wr_addr][wr_off][j] <= {DW_B{rst_n}} & wr_data_in[j];
                end
                if (ld_en[j] & ~wr_conflict) begin
                    mask_data[ld_addr][ld_off][j] <= {DW_B{rst_n}} & ld_data_in[j];
                end

                if (st_en[j]) begin
                    st_data_out[j]  <= {DW_B{rst_n}} & mask_data[st_addr][st_off][j];
                end
            end
        end
    endgenerate

endmodule
