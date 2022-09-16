
module FIFObuffer#(
    parameter DATA_WIDTH  = 32,
    parameter DEPTH_BITS  = 4,
    parameter DEPTH = (1 << DEPTH_BITS)
)(
    input                       clk, 
    input                       r_en, 
    input                       w_en, 
    input                       rst_n,

    output                      EMPTY,
    output                      FULL,
    output     [DEPTH_BITS-1:0] POP,

    input      [DATA_WIDTH-1:0] data_in,
    output     [DATA_WIDTH-1:0] data_out
);
// internal registers

reg  [DEPTH_BITS-1:0]    count = 0; 
(*ram_decomp="power"*) reg  [DATA_WIDTH-1:0]    FIFO [0:DEPTH-1]; 
reg  [DEPTH_BITS-1:0]    r_count_d = 0, w_count_d = 0;
wire [DEPTH_BITS-1:0]    r_count, w_count;

assign EMPTY    = ~(|count);
assign FULL     = &count;
assign POP      = count;

assign data_out = FIFO[r_count_d];

assign w_count  = rst_n ? (w_count_d + (w_en & ~FULL)) : 'h0;
assign r_count  = rst_n ? (r_count_d + (r_en & ~EMPTY)) : 'h0;

always @ (posedge clk) begin
    w_count_d   <= w_count;
    r_count_d   <= r_count;
    count       <= w_count - r_count;
end

always @ (posedge clk) begin
    if (rst_n & w_en & ~FULL) begin
        FIFO[w_count_d] <= data_in;
    end
end

endmodule

module mem_queue #(
    parameter MBUS_ADDR_WIDTH    = 32,               // We need to get this from VexRiscV
    parameter MBUS_DATA_WIDTH    = 32,
    parameter MBUS_DW_B          = MBUS_DATA_WIDTH>>3,
    parameter RVV_DATA_WIDTH     = 64,
    parameter RVV_DW_B           = RVV_DATA_WIDTH>>3,
    parameter FIFO_DEPTH_BITS    = 9
) (
    input                           clk,
    input                           rst_n,

    output  [ MBUS_ADDR_WIDTH-1:0]  mbus_ar_addr  ,
    output                          mbus_ar_valid ,
    input                           mbus_ar_ready ,
    input   [ MBUS_DATA_WIDTH-1:0]  mbus_r_data   ,
    input                           mbus_r_valid  ,
    output                          mbus_r_ready  ,

    output  [ MBUS_ADDR_WIDTH-1:0]  mbus_aw_addr  ,
    output                          mbus_aw_valid ,
    input                           mbus_aw_ready ,
    output  [ MBUS_DATA_WIDTH-1:0]  mbus_w_data   ,
    output                          mbus_w_valid  ,
    output  [       MBUS_DW_B-1:0]  mbus_w_strb   ,

    input                           mbus_b_resp  ,
    input                           mbus_b_valid ,
    output                          mbus_b_ready ,
    
    output  [  RVV_DATA_WIDTH-1:0]  rvv_data_in,
    output                          rvv_valid_in,
    input   [ MBUS_ADDR_WIDTH-1:0]  rvv_addr_out,
    input   [  RVV_DATA_WIDTH-1:0]  rvv_data_out,
    input                           rvv_valid_out,
    input                           rvv_req_out,
    input                           rvv_start_out,
    input   [        RVV_DW_B-1:0]  rvv_be_out,
    input                           rvv_ready_out,

    output                          rvv_done_ld,
    output                          rvv_done_st
    );

    wire                        ar_l_r_en,  ar_h_r_en,  r_r_en,     w_l_r_en,   w_h_r_en;
    wire                        ar_w_en,    w_w_en,     r_l_w_en,   r_h_w_en;

    wire [MBUS_DATA_WIDTH-1:0]  ar_l_din,   ar_h_din,   aw_l_din,   aw_h_din,   r_din,      w_l_din,    w_h_din;
    wire [MBUS_DATA_WIDTH-1:0]  ar_l_dout,  ar_h_dout,  aw_l_dout,  aw_h_dout,  r_l_dout,   r_h_dout,   w_l_dout,   w_h_dout;
    wire                        ar_l_empty, ar_h_empty, w_l_empty,  w_h_empty;
    wire                        r_l_full, r_h_full;

    reg  [FIFO_DEPTH_BITS-1:0]  burst_len;   // it's entirely possible we get 2048 element burst eventually, right?
    wire [FIFO_DEPTH_BITS-1:0]  r_l_pop,    r_h_pop;

    // track what turn we're on
    reg                         r_turn = 0;
    reg                         r_out  = 0; // indicated whether there is an outstanding read request
    reg                         w_turn = 0;

    reg                         mid_burst_r = 0;

    reg                         start_read = 0;
    reg [  FIFO_DEPTH_BITS-1:0] read_count = 0;

    reg [  FIFO_DEPTH_BITS-1:0] write_count = 0;
    reg [    FIFO_DEPTH_BITS:0] ack_count = 0;

    FIFObuffer #(.DATA_WIDTH(MBUS_ADDR_WIDTH),.DEPTH_BITS(FIFO_DEPTH_BITS)) ar_buf_h   (.clk(clk), .rst_n(rst_n), .r_en(ar_h_r_en),   .w_en(ar_w_en), .data_in(ar_h_din), .data_out(ar_h_dout), .EMPTY(ar_h_empty));
    FIFObuffer #(.DATA_WIDTH(MBUS_ADDR_WIDTH),.DEPTH_BITS(FIFO_DEPTH_BITS)) ar_buf_l   (.clk(clk), .rst_n(rst_n), .r_en(ar_l_r_en),   .w_en(ar_w_en), .data_in(ar_l_din), .data_out(ar_l_dout), .EMPTY(ar_l_empty));
    FIFObuffer #(.DATA_WIDTH(MBUS_ADDR_WIDTH),.DEPTH_BITS(FIFO_DEPTH_BITS)) aw_buf_h   (.clk(clk), .rst_n(rst_n), .r_en(w_h_r_en),    .w_en(w_w_en),  .data_in(aw_h_din), .data_out(aw_h_dout));
    FIFObuffer #(.DATA_WIDTH(MBUS_ADDR_WIDTH),.DEPTH_BITS(FIFO_DEPTH_BITS)) aw_buf_l   (.clk(clk), .rst_n(rst_n), .r_en(w_l_r_en),    .w_en(w_w_en),  .data_in(aw_l_din), .data_out(aw_l_dout));
    FIFObuffer #(.DATA_WIDTH(MBUS_DATA_WIDTH),.DEPTH_BITS(FIFO_DEPTH_BITS)) w_buf_h    (.clk(clk), .rst_n(rst_n), .r_en(w_h_r_en),    .w_en(w_w_en),  .data_in(w_h_din),  .data_out(w_h_dout),  .EMPTY(w_h_empty));
    FIFObuffer #(.DATA_WIDTH(MBUS_DATA_WIDTH),.DEPTH_BITS(FIFO_DEPTH_BITS)) w_buf_l    (.clk(clk), .rst_n(rst_n), .r_en(w_l_r_en),    .w_en(w_w_en),  .data_in(w_l_din),  .data_out(w_l_dout),  .EMPTY(w_l_empty));
    FIFObuffer #(.DATA_WIDTH(MBUS_DATA_WIDTH),.DEPTH_BITS(FIFO_DEPTH_BITS)) r_buf_h    (.clk(clk), .rst_n(rst_n), .r_en(r_r_en),      .w_en(r_h_w_en),.data_in(r_din),    .data_out(r_h_dout),  .POP(r_h_pop),  .FULL(r_h_full));
    FIFObuffer #(.DATA_WIDTH(MBUS_DATA_WIDTH),.DEPTH_BITS(FIFO_DEPTH_BITS)) r_buf_l    (.clk(clk), .rst_n(rst_n), .r_en(r_r_en),      .w_en(r_l_w_en),.data_in(r_din),    .data_out(r_l_dout),  .POP(r_l_pop),  .FULL(r_l_full));

    assign ar_h_din     = rvv_addr_out[31:0] + MBUS_DW_B;
    assign ar_l_din     = rvv_addr_out[31:0];

    assign r_din        = mbus_r_data;

    assign aw_h_din     = rvv_addr_out[31:0] + MBUS_DW_B;
    assign aw_l_din     = rvv_addr_out[31:0];

    assign w_h_din      = rvv_data_out[63:32];
    assign w_l_din      = rvv_data_out[31:0];

    assign ar_w_en      = rvv_req_out;
    assign ar_h_r_en    = r_turn & mbus_ar_ready;
    assign ar_l_r_en    = ~r_turn & mbus_ar_ready;

    assign r_h_w_en     = r_turn & mbus_r_valid & r_out;
    assign r_l_w_en     = ~r_turn & mbus_r_valid & r_out;

    always @(posedge clk) begin
        r_turn          <= mbus_ar_ready^r_turn;
        r_out           <= r_out ? ~mbus_r_valid : mbus_ar_ready; // signal that we have an un-acked request

        burst_len       <= (mid_burst_r | ar_w_en) ? burst_len + ar_w_en : ((read_count == burst_len) ? 0 : burst_len);   // if we're mid-burst, increment. Else, set to the enable signal value
        mid_burst_r     <= ar_w_en;

        start_read      <= (r_l_pop == (burst_len)) & (r_h_pop == (burst_len)) & (burst_len > 0) & rvv_ready_out;

        read_count      <= (read_count > 0) ? ((read_count < burst_len) ? read_count + 1 : 0) : (start_read ? 1 : 0);
    end

    assign mbus_ar_addr     = r_turn ? ar_h_dout : ar_l_dout;
    assign mbus_ar_valid    = ~ar_l_empty | ~ar_h_empty;
    assign mbus_r_ready     = r_out; // todo change this maybe idk
    
    assign r_r_en           = start_read | (read_count < burst_len & read_count > 0);
    assign rvv_valid_in     = r_r_en;
    assign rvv_data_in      = {r_l_dout, r_h_dout};
    
    assign rvv_done_ld      = (read_count == (burst_len - 1) & burst_len > 0 & read_count > 0);
    // must have both - FIXME we should wait until we have the right number of reqs back
    // FIXME integrate ready signal from processor lol

    // WRITE BUFFERING
    always @(posedge clk) begin
        w_turn          <= mbus_aw_ready^w_turn;

        write_count     <= rvv_valid_out ? (rvv_start_out ? 1 : write_count + 1) : (ack_count[FIFO_DEPTH_BITS-1:1] == write_count ? 0 : write_count);
        ack_count       <= (ack_count[FIFO_DEPTH_BITS-1:1] < write_count) ? (mbus_b_valid ? ack_count + 1 : ack_count) : 0;
    end

    assign w_w_en           = rvv_valid_out;

    assign mbus_b_ready     = 1;

    assign w_l_r_en         = ~w_turn & mbus_aw_ready;
    assign w_h_r_en         =  w_turn & mbus_aw_ready;

    assign mbus_aw_addr     =  w_turn ? aw_h_dout : aw_l_dout;
    assign mbus_aw_valid    =  mbus_w_valid;

    assign mbus_w_data      =  w_turn ? w_h_dout : w_l_dout;
    assign mbus_w_strb      = {MBUS_DW_B{1'b1}};
    assign mbus_w_valid     = ~w_l_empty | ~w_h_empty;

    assign rvv_done_st      = (ack_count[FIFO_DEPTH_BITS-1:1] == write_count) & (write_count > 0);
endmodule