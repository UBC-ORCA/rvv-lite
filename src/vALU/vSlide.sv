module vSlide 
  #(
    parameter REQ_DATA_WIDTH    = 64,
    parameter RESP_DATA_WIDTH   = 64,
    parameter REQ_ADDR_WIDTH    = 32,
    parameter SEW_WIDTH         = 3,
    parameter SHIFT_WIDTH       = $clog2(REQ_DATA_WIDTH/8),
    parameter REQ_BYTE_EN_WIDTH = 8,
    parameter ENABLE_64_BIT     = 1,
    parameter SLIDE_N_ENABLE    = 1
  ) 
  (
    input  logic clk,
    input  logic rst,
    input  logic in_valid,
    input  logic in_start,
    input  logic in_end,
    input  logic [REQ_DATA_WIDTH-1:0] in_vec0,
    input  logic [REQ_DATA_WIDTH-1:0] in_vec1,
    input  logic [SHIFT_WIDTH-1:0] in_shift,
    input  logic in_opSel , //0-up,1-down
    input  logic in_insert,
    input  logic [REQ_ADDR_WIDTH-1:0] in_addr,
    input  logic [REQ_BYTE_EN_WIDTH-1:0] in_be,
    input  logic [REQ_BYTE_EN_WIDTH-1:0] in_avl_be,
    input  logic [11:0] in_off ,
    output logic [REQ_BYTE_EN_WIDTH-1:0] out_be,
    output logic [RESP_DATA_WIDTH-1:0] out_vec,
    output logic out_valid,
    output logic [REQ_ADDR_WIDTH-1:0] out_addr,
    output logic [11:0] out_off
  );

    //TODO: SLIDE_N not supported

    localparam NUM_STAGES = 6;
    localparam OFF_WIDTH  = 12; 

    logic [REQ_ADDR_WIDTH-1:0] addrs[NUM_STAGES];
    logic [REQ_BYTE_EN_WIDTH-1:0] bes[NUM_STAGES];
    logic [REQ_BYTE_EN_WIDTH-1:0] avl_bes[NUM_STAGES];
    logic [OFF_WIDTH-1:0] offs[NUM_STAGES];
    logic [SHIFT_WIDTH-1:0] shifts[NUM_STAGES];
    logic [REQ_DATA_WIDTH-1:0] vecs[NUM_STAGES];
    logic valids[NUM_STAGES];
    logic inserts[NUM_STAGES];
    logic sels[NUM_STAGES];
    logic starts[NUM_STAGES];
    logic ends[NUM_STAGES];
    logic [2*REQ_DATA_WIDTH-1:0]  down_padded_vec0_s0;
    logic [2*REQ_DATA_WIDTH-1:0]  up_padded_vec0_s0;
    logic [REQ_DATA_WIDTH-1:0]    down_carried_vec0_s0,  down_carried_vec0_s1;
    logic [REQ_DATA_WIDTH-1:0]    down_carried_vec1_s0,  down_carried_vec1_s1;
    logic [REQ_DATA_WIDTH-1:0]    down_stripped_vec0_s0, down_stripped_vec0_s1;
    logic [REQ_DATA_WIDTH-1:0]    up_carried_vec0_s0,    up_carried_vec0_s1,   up_carried_vec0_s2;
    logic [REQ_DATA_WIDTH-1:0]    up_carried_vec1_s0,    up_carried_vec1_s1;
    logic [REQ_DATA_WIDTH-1:0]    up_stripped_vec0_s0,   up_stripped_vec0_s1;
    logic [REQ_DATA_WIDTH-1:0]    vec0_s0;
    logic [REQ_DATA_WIDTH-1:0]    vec1_s0;
    logic [REQ_BYTE_EN_WIDTH-1:0] down_masked_be_s1,  down_masked_be_s0;
    logic [REQ_BYTE_EN_WIDTH-1:0] up_masked_be_s1,    up_masked_be_s0;

    always_comb begin
      down_padded_vec0_s0 = {vec0_s0,{REQ_DATA_WIDTH{1'b0}}};
      up_padded_vec0_s0   = {{REQ_DATA_WIDTH{1'b0}},vec0_s0};

      if (inserts[0]) begin
        unique case (shifts[0][2:0])
          3'b001: begin
            {down_stripped_vec0_s0,down_carried_vec0_s0}    = down_padded_vec0_s0 >> 8;
            {up_carried_vec0_s0,up_stripped_vec0_s0}        = up_padded_vec0_s0   << 8;
            down_carried_vec1_s0                            = {vec1_s0[8-1:0],{(REQ_DATA_WIDTH-8){1'b0}}} >> clz_avl_be_s0*8;
            up_carried_vec1_s0                              = {{(REQ_DATA_WIDTH-8){1'b0}},vec1_s0[8-1:0]};
          end
          3'b010: begin 
            {down_stripped_vec0_s0,down_carried_vec0_s0}    = down_padded_vec0_s0 >> 16;
            {up_carried_vec0_s0,up_stripped_vec0_s0}        = up_padded_vec0_s0   << 16;
            down_carried_vec1_s0                            = {vec1_s0[16-1:0],{(REQ_DATA_WIDTH-16){1'b0}}} >> clz_avl_be_s0*8;
            up_carried_vec1_s0                              = {{(REQ_DATA_WIDTH-16){1'b0}},vec1_s0[16-1:0]};
          end
          3'b100: begin
            {down_stripped_vec0_s0,down_carried_vec0_s0}    = down_padded_vec0_s0 >> 32;
            {up_carried_vec0_s0,up_stripped_vec0_s0}        = up_padded_vec0_s0   << 32;
            down_carried_vec1_s0                            = {vec1_s0[32-1:0],{(REQ_DATA_WIDTH-32){1'b0}}} >> clz_avl_be_s0*8;
            up_carried_vec1_s0                              = {{(REQ_DATA_WIDTH-32){1'b0}},vec1_s0[32-1:0]};
          end
          default: begin
            if (ENABLE_64_BIT & REQ_DATA_WIDTH >= 64) begin
              {down_stripped_vec0_s0,down_carried_vec0_s0}  = down_padded_vec0_s0 >> 64;
              {up_carried_vec0_s0,up_stripped_vec0_s0}      = up_padded_vec0_s0   << 64;
              down_carried_vec1_s0                          = {vec1_s0[64-1:0],{(REQ_DATA_WIDTH-64){1'b0}}} >> clz_avl_be_s0*8;
              up_carried_vec1_s0                            = {{(REQ_DATA_WIDTH-64){1'b0}},vec1_s0[64-1:0]};
            end else begin
              {down_stripped_vec0_s0,down_carried_vec0_s0}  = down_padded_vec0_s0 >> 32;
              {up_carried_vec0_s0,up_stripped_vec0_s0}      = up_padded_vec0_s0   << 32;
              down_carried_vec1_s0                          = {vec1_s0[32-1:0],{(REQ_DATA_WIDTH-32){1'b0}}} >> clz_avl_be_s0*8;
              up_carried_vec1_s0                            = {{(REQ_DATA_WIDTH-32){1'b0}},vec1_s0[32-1:0]};
            end
          end
        endcase
      end else begin
        down_carried_vec1_s0 = (REQ_DATA_WIDTH)'(0);
        up_carried_vec1_s0   = (REQ_DATA_WIDTH)'(0);
        {down_stripped_vec0_s0,down_carried_vec0_s0} = (2*REQ_DATA_WIDTH)'(0);
        {up_carried_vec0_s0,up_stripped_vec0_s0}     = (2*REQ_DATA_WIDTH)'(0);
      end
    end

    always_ff @(posedge clk) begin
      vec0_s0     <= in_valid  ?  in_vec0 : (REQ_DATA_WIDTH)'(0);
      vec1_s0     <= in_valid  ?  in_vec1 : (REQ_DATA_WIDTH)'(0);
      addrs[0]    <= in_valid  ?  in_addr : (REQ_ADDR_WIDTH)'(0);
      bes[0]      <= in_valid  ?  in_be : (REQ_DATA_WIDTH/8)'(0);
      avl_bes[0]  <= in_valid  ?  in_avl_be : (REQ_DATA_WIDTH/8)'(0);
      ends[0]     <= in_valid  &  in_end;
      inserts[0]  <= in_valid  &  in_insert;
      offs[0]     <= in_valid  & ~in_opSel ? in_off : (OFF_WIDTH)'(0);
      sels[0]     <= in_valid  &  in_opSel;
      shifts[0]   <= in_valid  ?  in_shift : (SHIFT_WIDTH)'(0);
      starts[0]   <= in_valid  &  in_start;
      valids[0]   <= in_valid;

      for (int s = 1; s < NUM_STAGES; s++) begin
        addrs[s]    <= addrs[s-1];
        bes[s]      <= bes[s-1];
        avl_bes[s]  <= avl_bes[s-1];
        ends[s]     <= ends[s-1];
        inserts[s]  <= inserts[s-1];
        offs[s]     <= offs[s-1];
        sels[s]     <= sels[s-1];
        shifts[s]   <= shifts[s-1];
        starts[s]   <= starts[s-1];
        valids[s]   <= valids[s-1];
        vecs[s]     <= vecs[s-1];
      end

      /////////////////////////////////////////////////////////////////////////////////////////////

      down_carried_vec0_s1  <= down_carried_vec0_s0;
      down_carried_vec1_s1  <= down_carried_vec1_s0;
      down_stripped_vec0_s1 <= down_stripped_vec0_s0;

      up_carried_vec0_s1    <= up_carried_vec0_s0;
      up_carried_vec1_s1    <= up_carried_vec1_s0;
      up_stripped_vec0_s1   <= up_stripped_vec0_s0;
      up_carried_vec0_s2    <= up_carried_vec0_s1;

      down_masked_be_s1     <= down_masked_be_s0;
      up_masked_be_s1       <= up_masked_be_s0;

      if (sels[1]) begin // SLIDEDOWN
        if (ends[1]) begin
          vecs[2] <= down_stripped_vec0_s1 | down_carried_vec1_s1;
        end else begin
          vecs[2] <= down_stripped_vec0_s1 | down_carried_vec0_s0; // or-ed with next carry
        end
      end else begin    // SLIDEUP
        if (starts[1]) begin
          vecs[2] <= up_stripped_vec0_s1 | up_carried_vec1_s1;
        end else begin
          vecs[2] <= up_stripped_vec0_s1 | up_carried_vec0_s2;    // or-ed with previous carry
        end
      end

      /////////////////////////////////////////////////////////////////////////////////////////////

      if (rst) begin
        vec0_s0               <= (REQ_DATA_WIDTH)'(0);
        vec1_s0               <= (REQ_DATA_WIDTH)'(0);
        down_carried_vec0_s1  <= (REQ_DATA_WIDTH)'(0);
        down_carried_vec1_s1  <= (REQ_DATA_WIDTH)'(0);
        down_stripped_vec0_s1 <= (REQ_DATA_WIDTH)'(0);
        up_carried_vec0_s1    <= (REQ_DATA_WIDTH)'(0);
        up_carried_vec1_s1    <= (REQ_DATA_WIDTH)'(0);
        up_stripped_vec0_s1   <= (REQ_DATA_WIDTH)'(0);
        up_carried_vec0_s2    <= (REQ_DATA_WIDTH)'(0);
        down_masked_be_s1     <= (REQ_BYTE_EN_WIDTH)'(0);
        up_masked_be_s1       <= (REQ_BYTE_EN_WIDTH)'(0);

        for (int s = 0; s < NUM_STAGES; s++) begin
          addrs[s]    <= (REQ_ADDR_WIDTH)'(0);
          bes[s]      <= (REQ_BYTE_EN_WIDTH)'(0);
          avl_bes[s]  <= (REQ_BYTE_EN_WIDTH)'(0);
          ends[s]     <= 1'b0;
          inserts[s]  <= 1'b0;
          offs[s]     <= (OFF_WIDTH)'(0);
          sels[s]     <= 1'b0;
          shifts[s]   <= (SHIFT_WIDTH)'(0);
          starts[s]   <= 1'b0;
          valids[s]   <= 1'b0;
          vecs[s]     <= (REQ_DATA_WIDTH)'(0);
        end
      end
    end

    assign out_addr  = addrs[NUM_STAGES-1];
    assign out_vec   = valids[NUM_STAGES-1] ? vecs[NUM_STAGES-1] : (RESP_DATA_WIDTH)'(0); //FIXME
    assign out_valid = valids[NUM_STAGES-1];
    assign out_be    = bes[NUM_STAGES-1];
    assign out_off   = offs[NUM_STAGES-1];

    logic [(REQ_BYTE_EN_WIDTH == 1) ? 0 : ($clog2(REQ_BYTE_EN_WIDTH)-1) : 0] clz_avl_be_s0;
    CountLeadingZeros #(.WIDTH(REQ_BYTE_EN_WIDTH))
    clz_block (
      .in(avl_bes[0]),
      .out(clz_avl_be_s0));

endmodule

module CountLeadingZerosTree #(parameter L=8, parameter R=8)
  (input [L-1:0] left,
   input [R-1:0] right,
   output logic [$clog2(L+R+1)-1:0] out);

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

    for (i = $clog2(L+1)-1; i > $clog2(R+1)-1; --i) begin : extend
      assign rCountExtend[i] = 1'b0;
    end

    if (L >= 2) begin : lBranch
      CountLeadingZerosTree #(.L(L2), .R(L2))
      leftCount(left[(L-1)-:L2], left[L2-1:0], lCount);
    end else begin : lLeaf
      always_comb begin
        lCount = ~left[0];
      end
    end

    if (R >= 2) begin : rBranch
      CountLeadingZerosTree #(.L(R2A), .R(R2B))
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
        end else if (!lCount[$clog2(L+1)-1]) begin
          out = {1'b0, lCount};
        end else begin
          out = {2'b01, rCountExtend[$clog2(L+1)-2:0]};
        end

        // $display("%d %d: left %b right %b lcount %b rcount %b rcountext %b out %b",
        //          L, R, left, right, lCount, rCount, rCountExtend, out);
      end
    end else begin : makeCount2
      always_comb begin
        if (lCount[$clog2(L+1)-1] && rCountExtend[$clog2(L+1)-1]) begin
          out = {1'b1, {($clog2(L+R+1)-1){1'b0}}};
        end else if (!lCount[$clog2(L+1)-1]) begin
          out = {1'b0, lCount};
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
module CountLeadingZeros #(parameter WIDTH=74,
                           parameter ADD_OFFSET=0)
  (input [WIDTH-1:0] in,
   output logic [$clog2(WIDTH+1+ADD_OFFSET)-1:0] out);

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
    for (i = WIDTH+ADD_OFFSET-1; i >= WIDTH; --i) begin : in_pad
      assign inPad[i] = 1'b0;
    end

    assign inPad[WIDTH-1:0] = in;
  endgenerate

  CountLeadingZerosTree #(.L(L), .R(R))
  tree(inPad[(WIDTH+ADD_OFFSET-1)-:L], in[R-1:0], out);
endmodule
