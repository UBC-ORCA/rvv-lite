module cfg_unit #(
    parameter XLEN          = 32,
    parameter VLEN          = 16384,
    parameter DATA_WIDTH    = 64,
    parameter VLMAX         = VLEN >> 3,
    parameter VLEN_B_BITS   = 12  
) (
    input                           clk,
    input                           en,
    input       [      XLEN-1:0]    vtype_nxt,
    input       [           1:0]    cfg_type,
    input       [           4:0]    src_1,
    input       [           1:0]    avl_set,
    input       [VLEN_B_BITS-1:0]   avl_new,

    output reg  [VLEN_B_BITS-1:0]    avl,   // Application Vector Length (vlen effective)
    output reg  [           1:0]    sew,
    // output reg  [           2:0]    vlmul, // sew = vlmul for this when sew/vlmul = 8 (our setting)
    output reg                      vill,
    output reg                      new_vl
);
    wire [VLEN_B_BITS-1:0]   vlmax;
    
    wire [           1:0]   sew_nxt;
    // wire [           2:0]   vlmul_nxt;
    wire                    vill_nxt;

    // assign vlmul_nxt   = vtype_nxt[5:3];//vtype_nxt[2:0];
    assign sew_nxt     = vtype_nxt[4:3]; // only need bottom 2 bits (00,01,10,11)
    assign vill_nxt    = vtype_nxt[XLEN-1];
    // we only support 
    assign vlmax        = VLMAX;//~vlmul_nxt[2] ? (VLEN_B << vlmul_nxt) >> (sew_nxt) : (VLEN_B >> (3'b100 - vlmul_nxt[1:0] + sew_nxt));

    always @(posedge clk) begin
        if (en & cfg_type != 2'b10) begin
            // update vtype values if using vset{i}vli
            // vlmul   <= vlmul_nxt;
            sew     <= sew_nxt;
            vill    <= vill_nxt;
            // vlmax   <= vlmax_nxt;
        end // if (en)
    end // always @(posedge clk)

    always @(posedge clk) begin
        if (en) begin
            // Update AVL directly if using vsetivli
            // TODO: register version, which is more reasonable tbh (5 bits is too small for a vector lol)
            if (cfg_type === 2'b11) begin
                avl     <= src_1;
            end else begin
                if (~avl_set[0]) begin
                    avl <= (avl_new < VLMAX) ? avl_new : VLMAX; // This is a much simpler way to do it no?
                end else begin
                    if(~avl_set[1]) begin
                        avl <= VLMAX;
                    end
                end
            end
        end

        new_vl <= (en & ~(&avl_set));  // signals when to write back new vl
    end

endmodule