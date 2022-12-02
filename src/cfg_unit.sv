`define MIN(a,b) {(a > b) ? b : a};

module cfg_unit #(
    parameter XLEN          = 32,
    parameter VLEN          = 16384,
    parameter DATA_WIDTH    = 64,
    parameter VLMAX         = VLEN >> 3,
    parameter VLEN_B_BITS   = $clog2(VLMAX),
    parameter ENABLE_64_BIT = 1
) (
    input                           clk,
    input                           en,
    input       [      XLEN-1:0]    vtype_nxt,
    input       [           1:0]    cfg_type,
    input       [           1:0]    avl_set,
    input       [VLEN_B_BITS-1:0]   avl_new,

    output reg  [VLEN_B_BITS-1:0]    avl,   // Application Vector Length (vlen effective)
    output reg  [           1:0]    sew,    // sew = vlmul for this when sew/vlmul = 8 (our setting)
    output reg                      vill,
    output reg                      new_vl
);
    // wire [VLEN_B_BITS-1:0]   vlmax;
    
    wire [           1:0]   sew_nxt;
    wire                    vill_nxt;

    assign sew_nxt     = vtype_nxt[4:3]; // only need bottom 2 bits (00,01,10,11)
    assign vill_nxt    = vtype_nxt[XLEN-1] | (vtype_nxt[2:0] != vtype_nxt[5:3]);
    // we only support 1 mode
    // assign vlmax        = VLMAX;//~vlmul_nxt[2] ? (VLEN_B << vlmul_nxt) >> (sew_nxt) : (VLEN_B >> (3'b100 - vlmul_nxt[1:0] + sew_nxt));

    always @(posedge clk) begin
        if (en) begin
            // Update AVL directly if using vsetivli
            // TODO: register version, which is more reasonable tbh (5 bits is too small for a vector lol)
            case (avl_set)
                2'b00,
                2'b10:      avl <= (avl_new > 0) ? avl_new : avl;
                2'b01:      avl <= VLMAX;
                default:    avl <= avl;
            endcase // avl_set
            // avl <= ~(&avl_set) ? (avl_set[0] ? avl_new : VLMAX)
            //                     : avl;

            new_vl <=   ~(&avl_set); // signals when to write back new vl

            if (cfg_type[0] | ~cfg_type[1]) begin
                // update vtype values if using vset{i}vli
                sew <= sew_nxt;
            end

            vill    <= vill_nxt;
        end
    end

endmodule

