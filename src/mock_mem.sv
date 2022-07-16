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

    reg [7:0] mem [MEM_BYTES-1:0]; // byte addressable :)

    wire [ADDR_WIDTH-1:0] rd_addr_base;
    wire [ADDR_WIDTH-1:0] wr_addr_base;

    // ------------------------------- MEMORY INIT ----------------------------------------
    genvar i;
    genvar j;

    generate
        for (i = 0; i < MEM_BYTES; i=i+1) begin
            initial begin
                mem[i] = 'hFF;
            end
        end
    endgenerate

    assign rd_addr_base = rd_addr - ADDR_OFFSET;
    assign wr_addr_base = wr_addr - ADDR_OFFSET;

    // --------------------------- READING AND WRITING ------------------------------------
    generate
        for (j = 0; j < DW_B; j=j+1) begin
            always @(posedge clk) begin
                if (rd_en) begin
                    rd_data_out[((j+1)<<3)-1 : (j<<3)] <= {8{rst_n}} & mem[rd_addr_base + j];
                end

                if (wr_en) begin
                    mem[wr_addr_base + j] <= {8{rst_n}} & wr_data_in[((j+1)<<3)-1 : (j<<3)];
                end
            end
        end
    endgenerate
endmodule
