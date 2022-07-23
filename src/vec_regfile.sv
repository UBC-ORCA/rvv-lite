// TODO: change signals back to reg/wire in proc because vivado hates them :)

module vec_regfile #(
    parameter VLEN          = 128,          // bit length of a vector
    parameter ADDR_WIDTH    = 5,            // this gives us 32 vectors
    parameter DATA_WIDTH    = 64,           // this is one vector width -- fine for access from vector accel. not fine from mem (will need aux interface)
    parameter DW_B          = DATA_WIDTH/8, // DATA_WIDTH in bytes
    parameter OFF_BITS      = 8             // 2048/64 needs 8 bits
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

    reg [(VLEN/DATA_WIDTH)-1:0][DW_B-1:0][7:0] vec_data [0:(1 << ADDR_WIDTH)-1];
  
    wire                    wr_conflict;

    // --------------------------- DEBUG SIGNALS ------------------------------------
    // wire [      VLEN-1:0] vec_data_0;
    // wire [      VLEN-1:0] vec_data_1;
    // wire [      VLEN-1:0] vec_data_2;
    // wire [      VLEN-1:0] vec_data_3;
    // wire [      VLEN-1:0] vec_data_4;
    // wire [      VLEN-1:0] vec_data_5;
    // wire [      VLEN-1:0] vec_data_6;
    // wire [      VLEN-1:0] vec_data_7;
    // wire [      VLEN-1:0] vec_data_8;
    // wire [      VLEN-1:0] vec_data_9;
    // wire [      VLEN-1:0] vec_data_10;
    // wire [      VLEN-1:0] vec_data_11;
    // wire [      VLEN-1:0] vec_data_12;
    // wire [      VLEN-1:0] vec_data_13;
    // wire [      VLEN-1:0] vec_data_14;
    // wire [      VLEN-1:0] vec_data_15;
    // wire [      VLEN-1:0] vec_data_16;
    // wire [      VLEN-1:0] vec_data_17;
    // wire [      VLEN-1:0] vec_data_18;
    // wire [      VLEN-1:0] vec_data_19;
    // wire [      VLEN-1:0] vec_data_20;
    // wire [      VLEN-1:0] vec_data_21;
    // wire [      VLEN-1:0] vec_data_22;
    // wire [      VLEN-1:0] vec_data_23;
    // wire [      VLEN-1:0] vec_data_24;
    // wire [      VLEN-1:0] vec_data_25;
    // wire [      VLEN-1:0] vec_data_26;
    // wire [      VLEN-1:0] vec_data_27;
    // wire [      VLEN-1:0] vec_data_28;
    // wire [      VLEN-1:0] vec_data_29;
    // wire [      VLEN-1:0] vec_data_30;
    // wire [      VLEN-1:0] vec_data_31;
  
    // wire [DATA_WIDTH-1:0] read_out;

    // assign vec_data_0   = vec_data[0];
    // assign vec_data_1   = vec_data[1];
    // assign vec_data_2   = vec_data[2];
    // assign vec_data_3   = vec_data[3];
    // assign vec_data_4   = vec_data[4];
    // assign vec_data_5   = vec_data[5];
    // assign vec_data_6   = vec_data[6];
    // assign vec_data_7   = vec_data[7];
    // assign vec_data_8   = vec_data[8];
    // assign vec_data_9   = vec_data[9];
    // assign vec_data_10  = vec_data[10];
    // assign vec_data_11  = vec_data[11];
    // assign vec_data_12  = vec_data[12];
    // assign vec_data_13  = vec_data[13];
    // assign vec_data_14  = vec_data[14];
    // assign vec_data_15  = vec_data[15];
    // assign vec_data_16  = vec_data[16];
    // assign vec_data_17  = vec_data[17];
    // assign vec_data_18  = vec_data[18];
    // assign vec_data_19  = vec_data[19];
    // assign vec_data_20  = vec_data[20];
    // assign vec_data_21  = vec_data[21];
    // assign vec_data_22  = vec_data[22];
    // assign vec_data_23  = vec_data[23];
    // assign vec_data_24  = vec_data[24];
    // assign vec_data_25  = vec_data[25];
    // assign vec_data_26  = vec_data[26];
    // assign vec_data_27  = vec_data[27];
    // assign vec_data_28  = vec_data[28];
    // assign vec_data_29  = vec_data[29];
    // assign vec_data_30  = vec_data[30];
    // assign vec_data_31  = vec_data[31];

    // TODO: continuous register data
//     assign data_start = curr_reg + curr_idx;

    // TODO: make this hardcoded 2 read 1 write i guess

    // ----------------------------- REGISTER INIT --------------------------------------
    genvar i;
    genvar j;

    integer c, d;

    generate
        for (i = 0; i < (VLEN/DATA_WIDTH); i++) begin
            for (j = 0; j < DW_B; j=j+1) begin
                initial begin
                    for (c = 0; c < (1 << ADDR_WIDTH); c=c+1) begin
                        vec_data[c][i][j]   = c;
                    end
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
                  rd_data_out_1[(j+1)*8-1:j*8]    <= {DATA_WIDTH{rst_n}} & vec_data[rd_addr_1][rd_off_1][j];
                end
                if (rd_en_2[j]) begin
                  rd_data_out_2[(j+1)*8-1:j*8]    <= {DATA_WIDTH{rst_n}} & vec_data[rd_addr_2][rd_off_2][j];
                end

                // Prioritize reg writeback over load writeback. Realistically we shouldn't allow conflicts, but this is to be safe
                // FIXME
                if (wr_en[j]) begin
                  vec_data[wr_addr][wr_off][j] <= {DATA_WIDTH{rst_n}} & wr_data_in[(j+1)*8-1:j*8];
                end
              
                if (ld_en[j] & ~wr_conflict) begin
                    vec_data[ld_addr][ld_off][j] <= {DATA_WIDTH{rst_n}} & ld_data_in[(j+1)*8-1:j*8];
                end 

                if (st_en[j]) begin
                  st_data_out[(j+1)*8-1:j*8]  <= {DATA_WIDTH{rst_n}} & vec_data[st_addr][st_off][j];
                end
            end
        end
    endgenerate

endmodule