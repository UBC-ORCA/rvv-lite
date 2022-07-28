module vec_regfile #(
    parameter VLEN          = 16384,        // byte length of a vector
    parameter VLEN_B        = VLEN>>3,
    parameter ADDR_WIDTH    = 5,            // this gives us 32 vectors
    parameter DATA_WIDTH    = 64,           // this is one vector width -- fine for access from vector accel. not fine from mem (will need aux interface)
    parameter DW_B          = DATA_WIDTH>>3, // DATA_WIDTH in bytes
    parameter OFF_BITS      = 8,             // 2048/64 needs 8 bits
    parameter BYTE          = 8
) (
    // no data reset needed, if the user picks an unused register they get garbage data and that's their problem ¯\_(ツ)_/¯
    input                           clk,
    input                           rst_n,
    input       [      DW_B-1:0]    rd_en_1,
    input       [      DW_B-1:0]    rd_en_2,
    input       [      DW_B-1:0]    wr_en,
    input       [      DW_B-1:0]    st_en,
    input       [ADDR_WIDTH-1:0]    rd_addr_1,
    input       [ADDR_WIDTH-1:0]    rd_addr_2,
    input       [ADDR_WIDTH-1:0]    wr_addr,
    input       [ADDR_WIDTH-1:0]    st_addr,
    input       [  OFF_BITS-1:0]    rd_off_1, // offsets (because data_width < vlen)
    input       [  OFF_BITS-1:0]    rd_off_2,
    input       [  OFF_BITS-1:0]    wr_off,
    input       [  OFF_BITS-1:0]    st_off,
    input       [DATA_WIDTH-1:0]    wr_data_in, // write 64 bits at a time
    output reg  [DATA_WIDTH-1:0]    st_data_out,
    output reg  [DATA_WIDTH-1:0]    rd_data_out_1, // read 64 bits at a time
    output reg  [DATA_WIDTH-1:0]    rd_data_out_2 
);

    // redundant copies so we read from BRAMS
    reg          [DATA_WIDTH-1:0] vec_data_r [((VLEN/DATA_WIDTH) << ADDR_WIDTH)-1:0]; // packet addressable
    // reg          [DATA_WIDTH-1:0] vec_data_r2 [((VLEN/DATA_WIDTH) << ADDR_WIDTH)-1:0]; // packet addressable
    reg          [DATA_WIDTH-1:0] vec_data_st [((VLEN/DATA_WIDTH) << ADDR_WIDTH)-1:0]; // packet addressable

    // --------------------------- READING AND WRITING ------------------------------------

    // FIXME rename
    wire r_e;
    // wire r2_e;
    wire st_e;
    wire wr_e;

    assign r_e = |rd_en_1 | |rd_en_2 | |wr_en;
    // assign r2_e = |rd_en_2 | |wr_en;
    assign st_e = |st_en | |wr_en;
    // assign wr_e = |wr_en;

    integer j;
    always @(posedge clk) begin
        if (r_e) begin
            for (j = 0; j < DW_B; j=j+1) begin
                if (wr_en[j]) begin
                    vec_data_r[wr_addr*(VLEN/DATA_WIDTH)+wr_off][j*BYTE +: BYTE]  <= wr_data_in[j*BYTE +: BYTE];// : vec_data_r2[wr_addr][wr_off*DATA_WIDTH+i]);
                end
            end
            rd_data_out_1  <= vec_data_r[rd_addr_1*(VLEN/DATA_WIDTH) + rd_off_1];
            rd_data_out_2  <= vec_data_r[rd_addr_2*(VLEN/DATA_WIDTH) + rd_off_2];
        end

        // if (r2_e) begin
        //     for (j = 0; j < DW_B; j=j+1) begin
        //         if (wr_en[j]) begin
        //             vec_data_r2[wr_addr*(VLEN/DATA_WIDTH)+wr_off][j*BYTE +: BYTE]  <= wr_data_in[j*BYTE +: BYTE];// : vec_data_r2[wr_addr][wr_off*DATA_WIDTH+i]);
        //         end
        //     end
        //     rd_data_out_2  <= vec_data_r2[rd_addr_2*(VLEN/DATA_WIDTH) + rd_off_2];
        // end

        if (st_e) begin
            for (j = 0; j < DW_B; j=j+1) begin
                if (wr_en[j]) begin
                    vec_data_st[wr_addr*(VLEN/DATA_WIDTH)+wr_off][j*BYTE +: BYTE]  <= wr_data_in[j*BYTE +: BYTE];// : vec_data_r2[wr_addr][wr_off*DATA_WIDTH+i]);
                end
            end
            st_data_out  <= vec_data_st[st_addr*(VLEN/DATA_WIDTH) + st_off];
        end
    end

endmodule

module extend_mask #(
    parameter DATA_WIDTH    = 64,
    parameter DW_B          = DATA_WIDTH/8
    ) (
    input   [       DW_B-1:0] vmask_in,
    output  [ DATA_WIDTH-1:0] vmask_out
    );
    genvar i;

    // Generate mask byte enable based on SEW and current index in vector
    generate
        for (i = 0; i < DATA_WIDTH; i = i + 1) begin
            assign vmask_out[i] = vmask_in[i>>3];
        end
    endgenerate


endmodule

// module byte_reg #(
//     parameter VLEN          = 16384,        // byte length of a vector
//     parameter VLEN_B        = VLEN>>3,
//     parameter ADDR_WIDTH    = 5,            // this gives us 32 vectors
//     parameter DATA_WIDTH    = 64,           // this is one vector width -- fine for access from vector accel. not fine from mem (will need aux interface)
//     parameter DW_B          = DATA_WIDTH>>3, // DATA_WIDTH in bytes
//     parameter OFF_BITS      = 8             // 2048/64 needs 8 bits
// ) (
//     // no data reset needed, if the user picks an unused register they get garbage data and that's their problem ¯\_(ツ)_/¯
//     input                           clk,
//     input                           rst_n,
//     input                           rd_en,
//     input                           wr_en,
//     input       [ADDR_WIDTH-1:0]    rd_addr,
//     input       [ADDR_WIDTH-1:0]    wr_addr,
//     input       [           7:0]    wr_data_in, // write 64 bits at a time
//     output reg  [           7:0]    rd_data_out
// );

//     // TODO this should actually just make redundant copies so we read from BRAMS

//     reg             vec_data [((VLEN/8) << ADDR_WIDTH)-1:0]; // byte addressable
//     // reg         [VLEN-1:0] vec_data_r1 [0:(1 << ADDR_WIDTH)-1];
//     // reg         [VLEN-1:0] vec_data_r2 [0:(1 << ADDR_WIDTH)-1];
//     // reg         [VLEN-1:0] vec_data_st [0:(1 << ADDR_WIDTH)-1];

//     // reg         [(VLEN << ADDR_WIDTH)-1:0] vec_data_r1;
//     // reg         [(VLEN << ADDR_WIDTH)-1:0] vec_data_r2;
//     // reg         [(VLEN << ADDR_WIDTH)-1:0] vec_data_st;
  
//     // wire        [19:0] rd_off_1*DATA_WIDTH;
//     // wire        [19:0] rd_off_2*DATA_WIDTH;
//     // wire        [19:0] st_off*DATA_WIDTH;

//     // wire        [19:0] wr_off*DATA_WIDTH;

//     // ----------------------------- REGISTER INIT --------------------------------------
//     genvar i;
//     genvar j;

//     // initial begin
//         // vec_data   = 'h0;
//         // vec_data_r2   = 'h0;
//         // vec_data_st   = 'h0;
//     // end

//     // --------------------------- READING AND WRITING ------------------------------------

//     generate
//         // assign rd_off_1*DATA_WIDTH = rd_off_1*DATA_WIDTH;
//         // assign rd_off_2*DATA_WIDTH = rd_off_2*DATA_WIDTH;
//         // assign st_off*DATA_WIDTH = st_off*DATA_WIDTH;
//         // assign wr_off*DATA_WIDTH = wr_off*DATA_WIDTH;

//         // this is split into 2 parts because otherwise vivado hangs :)
//         for (j = 0; j < DATA_WIDTH; j=j+1) begin
//             // for (i = 0; i < 8; i=i+1) begin
//                 always @(posedge clk) begin
//                     if (wr_en[0]) begin
//                         vec_data_r1[wr_addr*(VLEN/DATA_WIDTH) + wr_off*DATA_WIDTH]  <= wr_data_in;// : vec_data_r1[wr_addr][wr_off*DATA_WIDTH+i]);
//                         vec_data_r2[wr_addr*(VLEN/DATA_WIDTH) + wr_off*DATA_WIDTH]  <= wr_data_in;
//                         vec_data_st[wr_addr*(VLEN/DATA_WIDTH) + wr_off*DATA_WIDTH]  <= wr_data_in;
//                       // vec_data_r2[wr_addr][wr_off*DATA_WIDTH+i]  <= rst_n & wr_data_in[j*BYTE +: BYTE];// : vec_data_r2[wr_addr][wr_off*DATA_WIDTH+i]);
//                       // vec_data_st[wr_addr][wr_off*DATA_WIDTH+i]  <= rst_n & wr_data_in[j*BYTE +: BYTE];// : vec_data_st[wr_addr][wr_off*DATA_WIDTH+i]);
//                     end
//                 end

//                 always @(posedge clk) begin
//                     if (rd_en_1[0]) begin
//                         rd_data_out_1  <= vec_data_r1[rd_addr_1*(VLEN/DATA_WIDTH) + rd_off_1*DATA_WIDTH];
//                     end
//                     if (rd_en_2[0]) begin
//                         rd_data_out_2  <= vec_data_r2[rd_addr_2*(VLEN/DATA_WIDTH) + rd_off_2*DATA_WIDTH];
//                     end
//                     if (st_en[0]) begin
//                         st_data_out    <= vec_data_st[st_addr*(VLEN/DATA_WIDTH) + st_off*DATA_WIDTH];
//                     end
//                 end
//             // end
//         end
//     endgenerate

// endmodule