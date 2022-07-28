module mask_regfile #(
    parameter VLEN          = 16384,      // bit length of a vector
    parameter VLEN_B        = VLEN>>3,   // byte length (mask length)
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
    // input       [      DW_B-1:0]    ld_en,
    input       [      DW_B-1:0]    st_en,
    input       [ADDR_WIDTH-1:0]    rd_addr_1,
    input       [ADDR_WIDTH-1:0]    rd_addr_2,
    input       [ADDR_WIDTH-1:0]    wr_addr,
    // input       [ADDR_WIDTH-1:0]    ld_addr,
    input       [ADDR_WIDTH-1:0]    st_addr,
    input       [  OFF_BITS-1:0]    rd_off_1, // offsets (because data_width < vlen)
    input       [  OFF_BITS-1:0]    rd_off_2,
    input       [  OFF_BITS-1:0]    wr_off,
    // input       [  OFF_BITS-1:0]    ld_off,
    input       [  OFF_BITS-1:0]    st_off,
    input       [DATA_WIDTH-1:0]    wr_data_in, // write 64 bits at a time
    output reg  [DATA_WIDTH-1:0]    st_data_out,
    output reg  [DATA_WIDTH-1:0]    rd_data_out_1, // read 64 bits at a time
    output reg  [DATA_WIDTH-1:0]    rd_data_out_2 
);
    // FIXME I'm pretty sure we can read more data at once but don't quote me on that 
    reg          [DW_B-1:0] mask_data_r [((VLEN_B/DW_B) << ADDR_WIDTH)-1:0]; // packet addressable
    // reg          [DW_B-1:0] mask_data_r2 [((VLEN_B/DW_B) << ADDR_WIDTH)-1:0]; // packet addressable
    reg          [DW_B-1:0] mask_data_st [((VLEN_B/DW_B) << ADDR_WIDTH)-1:0]; // packet addressable

    wire        [DW_B-1:0] r_data;
    // wire        [DW_B-1:0] r2_data;
    wire        [DW_B-1:0] st_data;

    wire        [DW_B-1:0] r_data_curr;
    // wire        [DW_B-1:0] r2_data_curr;
    wire        [DW_B-1:0] st_data_curr;

    // --------------------------- READING AND WRITING ------------------------------------
    wire r1_e;
    wire r2_e;
    wire st_e;
    wire wr_e;

    assign r1_e = |rd_en_1;
    assign r2_e = |rd_en_2;
    assign st_e = |st_en;
    assign wr_e = |wr_en;

    assign r_data_curr = mask_data_r[wr_addr*(VLEN_B/DW_B)+wr_off];
    assign r_data = (wr_data_in & wr_en) ^ (r_data_curr & ~wr_en);

    always @(posedge clk) begin
        if (wr_e) begin
            mask_data_r[wr_addr*(VLEN_B/DW_B)+wr_off]  <= r_data;// : mask_data_r2[wr_addr][wr_off*DATA_WIDTH+i]);
        end
        if (r1_e) begin
            rd_data_out_1  <= mask_data_r[rd_addr_1*(VLEN_B/DW_B) + rd_off_1];
        end
        if (r2_e) begin
            rd_data_out_2  <= mask_data_r[rd_addr_2*(VLEN_B/DW_B) + rd_off_2];
        end
    end

    // assign r2_data_curr = mask_data_r2[wr_addr*(VLEN_B/DW_B)+wr_off];
    // assign r2_data = (wr_data_in & wr_en) ^ (r1_data_curr & ~wr_en);

    // always @(posedge clk) begin
    //     if (wr_e) begin
    //         mask_data_r2[wr_addr*(VLEN_B/DW_B)+wr_off]  <= r2_data;// : mask_data_r2[wr_addr][wr_off*DATA_WIDTH+i]);
    //     end
    //     if (r2_e) begin
    //         rd_data_out_2  <= mask_data_r2[rd_addr_2*(VLEN_B/DW_B) + rd_off_2];
    //     end
    // end

    assign st_data_curr = mask_data_st[wr_addr*(VLEN_B/DW_B)+wr_off];
    assign st_data = (wr_data_in & wr_en) ^ (st_data_curr & ~wr_en);

    always @(posedge clk) begin
        if (wr_e) begin
            mask_data_st[wr_addr*(VLEN_B/DW_B)+wr_off]  <= st_data;// : mask_data_r2[wr_addr][wr_off*DATA_WIDTH+i]);
        end
        if (st_e) begin
            st_data_out  <= mask_data_st[st_addr*(VLEN_B/DW_B) + st_off];
        end
    end

endmodule
