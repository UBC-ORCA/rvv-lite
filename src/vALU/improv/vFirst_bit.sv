module vFirst_bit 
  #(
    parameter REQ_DATA_WIDTH  = 64,
    parameter RESP_DATA_WIDTH = 64,
    parameter IDX_BITS        = 10
  ) 
  (
    input  logic clk,
    input  logic rst,
    input  logic in_valid,
    input  logic [IDX_BITS-1:0] in_idx,
    input  logic [REQ_DATA_WIDTH-1:0] in_m0,
    output logic [RESP_DATA_WIDTH-1:0] out_vec,
    output logic out_found
  );

  logic [$clog2(REQ_DATA_WIDTH+1)-1:0] lz_count;

  ctz #(
    .WIDTH(REQ_DATA_WIDTH), 
    .ADD_OFFSET(0)) 
  ctz_block(
    .in(in_m0),
    .out(lz_count));

  always_ff @(posedge clk) begin
    if (in_valid) begin
      out_vec <= in_idx + lz_count[$high(lz_count)-1:0];
      out_found <= ~lz_count[$high(lz_count)];
    end else begin
      out_vec <= 0;
      out_found <= 0;
    end

    if (rst) begin
      out_vec <= 0;
      out_found <= 0;
    end
  end

endmodule

module ctz_tree 
  #(
    parameter L = 8, 
    parameter R = 8
  )
  (
    input  logic [L-1:0] left, 
    input  logic [R-1:0] right,
    output logic [$clog2(L+R+1)-1:0] out
  );

  // L is always a power of 2; R might not be
  localparam L2 = L / 2;

  // The new L for the right-hand recursion should be a power of 2 as
  // well
  localparam R2A = 2 ** ($clog2(R) - 1);

  // floor(R / 2)
  localparam R2B = R - R2A;

  initial begin
    assert(L > 0);
    assert(R > 0);
    assert($clog2(L) == $clog2(L+1) - 1);
    assert(L >= R);
  end

  logic [$clog2(L+1)-1:0] lCount;
  logic [$clog2(R+1)-1:0] rCount;

  logic [$clog2(L+1)-1:0] rCountExtend;

  genvar i;

  generate
    assign rCountExtend[$clog2(R+1)-1:0] = rCount;

    for (i = $clog2(L+1)-1; i > $clog2(R+1)-1; i--) begin : extend
      assign rCountExtend[i] = 1'b0;
    end

    if (L >= 2) begin : lBranch
      ctz_tree #(.L(L2), .R(L2))
      leftCount(left[(L-1)-:L2], left[L2-1:0], lCount);
    end else begin : lLeaf
      always_comb begin
        lCount = ~left[0];
      end
    end

    if (R >= 2) begin : rBranch
      ctz_tree #(.L(R2A), .R(R2B))
      leftCount(right[(R-1)-:R2A], right[R2B-1:0], rCount);
    end else begin : rLeaf
      always_comb begin
        rCount = ~right[0];
      end
    end

    if ($clog2(L+1) > 1) begin : makeCount1
      always_comb begin
        if (lCount[$clog2(L+1)-1] && rCountExtend[$clog2(L+1)-1]) begin
          out = {1'b1, {($clog2(L+R+1)-1){1'b0}}};
        end else if (!rCountExtend[$clog2(L+1)-1]) begin
          out = {1'b0, rCountExtend};
        end else begin
          out = {2'b01, lCount[$clog2(L+1)-2:0]};
        end

        // $display("%d %d: left %b right %b lcount %b rcount %b rcountext %b out %b",
        //          L, R, left, right, lCount, rCount, rCountExtend, out);
      end
    end else begin : makeCount2
      always_comb begin
        if (lCount[$clog2(L+1)-1] && rCountExtend[$clog2(L+1)-1]) begin
          out = {1'b1, {($clog2(L+R+1)-1){1'b0}}};
        end else if (!rCountExtend[$clog2(L+1)-1]) begin
          out = {1'b0, rCountExtend};
        end else begin
          out = {2'b01};
        end

        // $display("%d %d: left %b right %b lcount %b rcount %b rcountext %b out %b",
        //          L, R, left, right, lCount, rCount, rCountExtend, out);
      end
    end
  endgenerate
endmodule

// ADD_OFFSET is in effect a constant added to `out`, so as to avoid an
// additional adder in a case where one wants to shift past a leading 1, for
// example
module ctz 
  #(
    parameter WIDTH      = 74,
    parameter ADD_OFFSET = 0
  )
  (
    input logic [WIDTH-1:0] in,
    output logic [$clog2(WIDTH+1+ADD_OFFSET)-1:0] out
  );

  // What's the largest power of 2 divisor of WIDTH?
  localparam L = 2 ** ($clog2(WIDTH + ADD_OFFSET) - 1);
  localparam R = WIDTH + ADD_OFFSET - L;

  initial begin
    assert(L >= R);
    assert(L > 0);
    assert(R > 0);
  end

  logic [WIDTH+ADD_OFFSET-1:0] inPad;

  genvar i;
  generate
    for (i = WIDTH+ADD_OFFSET-1; i >= WIDTH; i--) begin : in_pad
      assign inPad[i] = 1'b0;
    end

    assign inPad[WIDTH-1:0] = in;
  endgenerate

  ctz_tree #(
    .L(L),
    .R(R))
  tree (
    .left(inPad[(WIDTH+ADD_OFFSET-1)-:L]), 
    .right(in[R-1:0]), 
    .out(out));

endmodule
