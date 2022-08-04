module vec_regfile #(
    parameter VLEN          = 16384,        // byte length of a vector
    parameter ADDR_WIDTH    = 5,            // this gives us 32 vectors
    parameter DATA_WIDTH    = 64,           // this is one vector width -- fine for access from vector accel. not fine from mem (will need aux interface)
    parameter DW_B          = DATA_WIDTH>>3, // DATA_WIDTH in bytes
    parameter OFF_BITS      = 8,             // 2048/64 needs 8 bits
    parameter BYTE          = 8,
    parameter PACK_PER_REG  = VLEN/DATA_WIDTH
) (
    // no data reset needed, if the user picks an unused register they get garbage data and that's their problem ¯\_(ツ)_/¯
    input                           clk,
    input                           rst_n,
    input                           rd_en_1,
    input                           rd_en_2,
    input       [      DW_B-1:0]    wr_en,
    input       [ADDR_WIDTH-1:0]    rd_addr_1,
    input       [ADDR_WIDTH-1:0]    rd_addr_2,
    input       [ADDR_WIDTH-1:0]    wr_addr,
    input       [  OFF_BITS-1:0]    rd_off_1, // offsets (because data_width < vlen)
    input       [  OFF_BITS-1:0]    rd_off_2,
    input       [  OFF_BITS-1:0]    wr_off,
    input       [DATA_WIDTH-1:0]    wr_data_in, // write 64 bits at a time
    output reg  [DATA_WIDTH-1:0]    rd_data_out_1, // read 64 bits at a time
    output reg  [DATA_WIDTH-1:0]    rd_data_out_2 
);

    // redundant copies so we read from BRAMS
    (*ram_decomp = "power"*) reg [DATA_WIDTH-1:0]    vec_data    [(PACK_PER_REG << ADDR_WIDTH)-1:0]; // packet addressable

    // --------------------------- READING AND WRITING ------------------------------------

    // wire p1_e   = rd_en_1 | |wr_en;

    integer j;
    always @(posedge clk) begin
        for (j = 0; j < DW_B; j=j+1) begin
            if (wr_en[j]) begin
                vec_data[wr_addr*PACK_PER_REG+wr_off][j*BYTE +: BYTE]  <= wr_data_in[j*BYTE +: BYTE];
            end
        end
        if (rd_en_1) begin
            rd_data_out_1  <= vec_data[rd_addr_1*PACK_PER_REG + rd_off_1];
        end
    end
        
    always @(posedge clk) begin
        if (rd_en_2) begin
            rd_data_out_2  <= vec_data[rd_addr_2*PACK_PER_REG + rd_off_2];
        end
    end

endmodule