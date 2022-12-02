// Copyright 2021 The CFU-Playground Authors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
`include "rvv_proc_main.sv"
`include "mock_mem.sv"

`define VLEN           64           // vector length in bits
`define XLEN           32           // not sure, data width maybe?
`define NUM_VEC        32           // number of available vector registers
`define INSN_WIDTH     32           // width of a single instruction
`define DATA_WIDTH     64
`define MEM_ADDR_WIDTH 32           // WE ONLY HAVE MEM ADDRESSES AS REGISTER IDS RIGHT NOW
`define MEM_DATA_WIDTH 32
`define MEM_DW_B       `MEM_DATA_WIDTH/8
`define VEX_DATA_WIDTH 32
`define DW_B           `DATA_WIDTH/8
`define FIFO_DEPTH_BITS 5

module Vfu (
    input                           clk,
    input                           reset,

    input                           cmd_valid,
    output                          cmd_ready,
    input   [     `INSN_WIDTH-1:0]  cmd_payload_instruction,
    input   [ `VEX_DATA_WIDTH-1:0]  cmd_payload_inputs_0,
    input   [ `VEX_DATA_WIDTH-1:0]  cmd_payload_inputs_1,
    input   [                 2:0]  cmd_payload_rounding,
    output                          rsp_valid,
    input                           rsp_ready,
    output  [ `VEX_DATA_WIDTH-1:0]  rsp_payload_output,

    output  [ `MEM_ADDR_WIDTH-1:0]  mbus_ar_addr  ,
    output                          mbus_ar_valid ,
    input                           mbus_ar_ready ,
    input   [ `MEM_DATA_WIDTH-1:0]  mbus_r_data   ,
    input                           mbus_r_valid  ,
    output                          mbus_r_ready  ,

    output  [ `MEM_ADDR_WIDTH-1:0]  mbus_aw_addr  ,
    output                          mbus_aw_valid ,
    input                           mbus_aw_ready ,
    output  [ `MEM_DATA_WIDTH-1:0]  mbus_w_data   ,
    output                          mbus_w_valid  ,
    output  [       `MEM_DW_B-1:0]  mbus_w_strb   ,

    input                           mbus_b_resp  ,
    input                           mbus_b_valid ,
    output                          mbus_b_ready
    );
  
    wire    [     `DATA_WIDTH-1:0]  mem_port_data_in;
    wire                            mem_port_valid_in;
    wire    [ `MEM_ADDR_WIDTH-1:0]  mem_port_addr_out;
    wire    [     `DATA_WIDTH-1:0]  mem_port_data_out;
    wire                            mem_port_valid_out;
    wire                            mem_port_req_out;
    wire    [           `DW_B-1:0]  mem_port_be_out;


    rvv_proc_main #(.VLEN(`VLEN), .XLEN(`XLEN), .NUM_VEC(`NUM_VEC), .INSN_WIDTH(`INSN_WIDTH), .DATA_WIDTH(`DATA_WIDTH), .MEM_ADDR_WIDTH(`MEM_ADDR_WIDTH))
          rvv_proc (.clk(clk), .rst_n(~reset), .insn_in(cmd_payload_instruction), .insn_valid(cmd_valid), .mem_port_be_out(mem_port_be_out),
                    .mem_port_data_in(mem_port_data_in), .mem_port_valid_in(mem_port_valid_in), .mem_port_addr_out(mem_port_addr_out),
                    .mem_port_data_out(mem_port_data_out), .mem_port_req_out(mem_port_req_out), .mem_port_valid_out(mem_port_valid_out),
                    .proc_rdy(cmd_ready), .vexrv_data_in_1(cmd_payload_inputs_0), .vexrv_data_in_2(cmd_payload_inputs_1),
                    .vexrv_data_out(rsp_payload_output), .vexrv_valid_out(rsp_valid));

    wire                        ar_w_en;
    wire [`MEM_DATA_WIDTH-1:0]  ar_l_din;
    wire [`MEM_DATA_WIDTH-1:0]  ar_l_dout;
    wire                        ar_l_r_en;
    wire                        ar_l_full;
    wire                        ar_l_empty;

    wire [`MEM_DATA_WIDTH-1:0]  ar_h_din;
    wire [`MEM_DATA_WIDTH-1:0]  ar_h_dout;
    wire                        ar_h_r_en;
    wire                        ar_h_full;
    wire                        ar_h_empty;

    wire [`MEM_DATA_WIDTH-1:0]  aw_l_din;
    wire [`MEM_DATA_WIDTH-1:0]  aw_l_dout;
    wire                        aw_l_r_en;
    wire                        aw_l_full;
    wire                        aw_l_empty;

    wire [`MEM_DATA_WIDTH-1:0]  aw_h_din;
    wire [`MEM_DATA_WIDTH-1:0]  aw_h_dout;
    wire                        aw_h_r_en;
    wire                        aw_h_full;
    wire                        aw_h_empty;

    wire                        w_w_en;
    wire [`MEM_DATA_WIDTH-1:0]  w_l_din;
    wire [`MEM_DATA_WIDTH-1:0]  w_l_dout;
    wire                        w_l_r_en;
    wire                        w_l_full;
    wire                        w_l_empty;

    wire [`MEM_DATA_WIDTH-1:0]  w_h_din;
    wire [`MEM_DATA_WIDTH-1:0]  w_h_dout;
    wire                        w_h_r_en;
    wire                        w_h_full;
    wire                        w_h_empty;

    wire                        r_r_en;
    wire [`MEM_DATA_WIDTH-1:0]  r_l_din;
    wire [`MEM_DATA_WIDTH-1:0]  r_l_dout;
    wire                        r_l_w_en;
    wire                        r_l_full;
    wire                        r_l_empty;

    wire [`MEM_DATA_WIDTH-1:0]  r_h_din;
    wire [`MEM_DATA_WIDTH-1:0]  r_h_dout;
    wire                        r_h_w_en;
    wire                        r_h_full;
    wire                        r_h_empty;

    reg [ `FIFO_DEPTH_BITS-1:0] burst_len;   // it's entirely possible we get 2048 element burst eventually, right?
    reg [ `FIFO_DEPTH_BITS-1:0] r_l_pop;
    reg [ `FIFO_DEPTH_BITS-1:0] r_h_pop;

    // track what turn we're on
    reg                         r_turn = 0;
    reg                         r_out  = 0; // indicated whether there is an outstanding read request
    reg                         w_turn = 0;

    reg                         mid_burst = 0;

    reg                         start_read = 0;
    reg [ `FIFO_DEPTH_BITS-1:0] read_count = 0;

    FIFObuffer #(.DATA_WIDTH(`MEM_ADDR_WIDTH),.DEPTH_BITS(`FIFO_DEPTH_BITS)) ar_buf_h(.clk(clk),.rst_n(~reset),.r_en(ar_h_r_en),.w_en(ar_w_en),.data_in(ar_h_din),.data_out(ar_h_dout),.FULL(ar_h_full),.EMPTY(ar_h_empty));
    FIFObuffer #(.DATA_WIDTH(`MEM_ADDR_WIDTH),.DEPTH_BITS(`FIFO_DEPTH_BITS)) ar_buf_l(.clk(clk),.rst_n(~reset),.r_en(ar_l_r_en),.w_en(ar_w_en),.data_in(ar_l_din),.data_out(ar_l_dout),.FULL(ar_l_full),.EMPTY(ar_l_empty));
    FIFObuffer #(.DATA_WIDTH(`MEM_ADDR_WIDTH),.DEPTH_BITS(`FIFO_DEPTH_BITS)) aw_buf_h(.clk(clk),.rst_n(~reset),.r_en(aw_h_r_en),.w_en(w_w_en),.data_in(aw_h_din),.data_out(aw_h_dout),.FULL(aw_h_full),.EMPTY(aw_h_empty));
    FIFObuffer #(.DATA_WIDTH(`MEM_ADDR_WIDTH),.DEPTH_BITS(`FIFO_DEPTH_BITS)) aw_buf_l(.clk(clk),.rst_n(~reset),.r_en(aw_l_r_en),.w_en(w_w_en),.data_in(aw_l_din),.data_out(aw_l_dout),.FULL(aw_l_full),.EMPTY(aw_l_empty));
    FIFObuffer #(.DATA_WIDTH(`MEM_DATA_WIDTH),.DEPTH_BITS(`FIFO_DEPTH_BITS)) w_buf_h (.clk(clk),.rst_n(~reset),.r_en(w_h_r_en),.w_en(w_w_en),.data_in(w_h_din),.data_out(w_h_dout),.FULL(w_h_full),.EMPTY(w_h_empty));
    FIFObuffer #(.DATA_WIDTH(`MEM_DATA_WIDTH),.DEPTH_BITS(`FIFO_DEPTH_BITS)) w_buf_l (.clk(clk),.rst_n(~reset),.r_en(w_l_r_en),.w_en(w_w_en),.data_in(w_l_din),.data_out(w_l_dout),.FULL(w_l_full),.EMPTY(w_l_empty));
    FIFObuffer #(.DATA_WIDTH(`MEM_DATA_WIDTH),.DEPTH_BITS(`FIFO_DEPTH_BITS)) r_buf_h (.clk(clk),.rst_n(~reset),.r_en(r_r_en),.w_en(r_h_w_en),.data_in(r_h_din),.data_out(r_h_dout),.FULL(r_h_full),.EMPTY(r_h_empty),.POP(r_h_pop));
    FIFObuffer #(.DATA_WIDTH(`MEM_DATA_WIDTH),.DEPTH_BITS(`FIFO_DEPTH_BITS)) r_buf_l (.clk(clk),.rst_n(~reset),.r_en(r_r_en),.w_en(r_l_w_en),.data_in(r_l_din),.data_out(r_l_dout),.FULL(r_l_full),.EMPTY(r_l_empty),.POP(r_l_pop));

    assign ar_h_din = mem_port_addr_out[31:0];
    assign ar_l_din = mem_port_addr_out[31:0] + `MEM_DW_B;

    assign r_l_din  = mbus_r_data;
    assign r_h_din  = mbus_r_data;

    assign aw_h_din = mem_port_addr_out[31:0];
    assign aw_l_din = mem_port_addr_out[31:0] + `MEM_DW_B;

    assign w_h_din  = mem_port_data_out[63:32];
    assign w_l_din  = mem_port_data_out[31:0];

    assign ar_w_en  = mem_port_req_out;
    assign ar_h_r_en = r_turn & mbus_ar_ready;
    assign ar_l_r_en = ~r_turn & mbus_ar_ready;

    assign r_h_w_en = r_turn & mbus_r_valid & r_out;
    assign r_l_w_en = ~r_turn & mbus_r_valid & r_out;

    always @(posedge clk) begin
        r_turn              <= mbus_ar_ready^r_turn;
        r_out               <= (r_out & ~mbus_r_valid) | (~r_out & mbus_ar_ready); // signal that we have sent a request

        burst_len           <= mid_burst ? burst_len + ar_w_en : ((read_count == burst_len) ? 0 : burst_len);   // if we're mid-burst, increment. Else, set to the enable signal value
        mid_burst           <= ar_w_en;

        start_read          <= (r_l_pop === (burst_len + 1)) & (r_h_pop === (burst_len + 1)) & (burst_len > 0);
        // read_count          <= start_read ? 1 : ((read_count < (burst_len-1) & read_count > 0) ? read_count + 1 : 0);

        read_count          <= (read_count > 0) ? ((read_count < burst_len) ? read_count + 1 : 0) : (start_read ? 1 : 0);
    end

    assign mbus_ar_addr       = r_turn ? ar_h_dout : ar_l_dout;
    assign mbus_ar_valid      = ~ar_l_empty | ~ar_h_empty;
    assign mbus_r_ready       = r_out; // todo change this maybe idk
    
    assign mem_port_data_in   = {r_h_dout, r_l_dout};

    assign r_r_en             = start_read | (read_count > 0);//~(r_l_empty | r_h_empty);
    assign mem_port_valid_in  = r_r_en;

    assign r_w_en             = mbus_r_valid;
    // must have both - FIXME we should wait until we have the right number of reqs back
    // FIXME integrate ready signal from processor lol

    // WRITE BUFFERING
    always @(posedge clk) begin
        w_turn     <= mbus_aw_ready^w_turn;
    end

    assign mbus_aw_addr     = w_turn ? aw_h_dout : aw_l_dout;
    assign mbus_aw_valid    = ~aw_l_empty | ~aw_h_empty;

    assign mbus_w_data      = w_turn ? w_h_dout : w_l_dout;
    assign mbus_w_strb      = {`MEM_DW_B{1'b1}};
    assign mbus_w_valid     = ~w_l_empty | ~w_h_empty;

    assign mbus_b_ready     = 1;

    assign w_w_en           = mem_port_valid_out;

    assign w_l_r_en         = ~w_turn & mbus_aw_ready;
    assign w_h_r_en         = w_turn & mbus_aw_ready;

    assign aw_l_r_en        = ~w_turn & mbus_aw_ready;
    assign aw_h_r_en        = w_turn & mbus_aw_ready;

    // TODO ACTUALLY PIPE DATA BETWEEN FIFOS AND I/O
    // TODO TRACK BURST SIZE FOR READ (SHOULD MATCH BEFORE READING DATA) -- else implement pending queue for load AGU

endmodule

// Modified from https://esrd2014.blogspot.com/p/first-in-first-out-buffer.html
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
    output reg [DATA_WIDTH-1:0] data_out
);
// internal registers

reg  [DEPTH_BITS-1:0]    count = 0; 
reg  [DATA_WIDTH-1:0]    FIFO [0:DEPTH-1]; 
reg  [DEPTH_BITS-1:0]    r_count_d = 0, w_count_d = 0;
wire [DEPTH_BITS-1:0]    r_count, w_count;

assign EMPTY    = ~(|count);
assign FULL     = &count;
assign POP      = w_count_d - r_count_d;

assign data_out = {DATA_WIDTH{rst_n}} & FIFO[r_count_d];

assign w_count  = {DEPTH_BITS{rst_n & (w_count_d < DEPTH)}} & (w_count_d + (w_en & ~FULL));
assign r_count  = {DEPTH_BITS{rst_n & (r_count_d < DEPTH)}} & (r_count_d + (r_en & ~EMPTY));

always @ (posedge clk) begin
    w_count_d   <= w_count;
    r_count_d   <= r_count;

    count       <= w_count_d - r_count_d;

    // data_out <= {DATA_WIDTH{rst_n & r_en & (|(count))}} & FIFO[r_count];
    if (w_en) begin
        FIFO[w_count_d] <= {DATA_WIDTH{rst_n & ~FULL}} & data_in;
    end
end

// assign count = (w_count > r_count) ? (w_count - r_count) : (r_count - w_count);

endmodule

module mem_queue #(
    parameter MBUS_ADDR_WIDTH    = 32,               // We need to get this from VexRiscV
    parameter MBUS_DATA_WIDTH    = 32,
    parameter MBUS_DW_B          = MEM_DATA_WIDTH>>3,
    parameter RVV_DATA_WIDTH     = 64,
    parameter RVV_DW_B           = RVV_DATA_WIDTH>>3
) (
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
    input   [        RVV_DW_B-1:0]  rvv_be_out
    );



endmodule