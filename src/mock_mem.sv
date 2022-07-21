module mock_mem #(
    parameter MEM_BYTES     = 4096, // 4 kB memory? is that good for now?
    parameter ADDR_WIDTH    = 32,             // this gives us 32 vectors
    parameter DATA_WIDTH    = 64,              // this is one vector width -- fine for access from vector accel. not fine from mem (will need aux interface)
    parameter ADDR_OFFSET   = 'h41FFF000
) (
    // no data reset needed, if the user picks an unused register they get garbage data and that's their problem ¯\_(ツ)_/¯
    input                           clk,
    input                           rst_n,
    input                           rd_en,
    input                           wr_en,
    input       [ADDR_WIDTH-1:0]    rd_addr,
    input       [ADDR_WIDTH-1:0]    wr_addr,
    input       [DATA_WIDTH-1:0]    wr_data_in, // write 64 bits at a time
    output reg  [DATA_WIDTH-1:0]    rd_data_out // read 64 bits at a time
);
    parameter DW_B = DATA_WIDTH/8;

    reg [DATA_WIDTH-1:0] mem [(MEM_BYTES>>3)-1:0]; // word addressable I guess????

    wire [ADDR_WIDTH-1:0] rd_addr_base;
    wire [ADDR_WIDTH-1:0] wr_addr_base;

    // ------------------------------- MEMORY INIT ----------------------------------------
    genvar j;

    assign rd_addr_base = (rd_addr - ADDR_OFFSET) >> 3;
    assign wr_addr_base = (wr_addr - ADDR_OFFSET) >> 3;

    // --------------------------- READING AND WRITING ------------------------------------
    generate
        always @(posedge clk) begin
            if (rd_en) begin
                rd_data_out <= {DATA_WIDTH{rst_n}} & mem[rd_addr_base];
            end

            if (wr_en) begin
                mem[wr_addr_base] <= {DATA_WIDTH{rst_n}} & wr_data_in;
            end
        end
    endgenerate
endmodule
