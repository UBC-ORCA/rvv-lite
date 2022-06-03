module cfg_unit #(
    parameter XLEN          = 32,
    parameter VLEN          = 64,
    parameter DATA_WIDTH    = 64,
    parameter VLEN_B        = VLEN >> 3,
    parameter NUM_VEC       = 32
) (
    input                           clk,
    input                           rst_n,
    input                           en,
    input       [      XLEN-1:0]    vtype_nxt,
    input       [           1:0]    cfg_type,
    input       [           4:0]    src_1,
    input       [           1:0]    avl_set,
    input       [DATA_WIDTH-1:0]    avl_new,

    output reg  [DATA_WIDTH-1:0]    avl,   // Application Vector Length (vlen effective)
    output reg  [           2:0]    sew,
    output reg  [           2:0]    vlmul,
    output reg                      vma,
    output reg                      vta,
    output reg                      vill,
    output reg                      new_vl
);
    reg  [DATA_WIDTH-1:0] vlmax;
    
    wire [DATA_WIDTH-1:0]   vlmax_nxt;
    wire [           2:0]   sew_nxt;
    wire [           2:0]   vlmul_nxt;
    wire                    vma_nxt;
    wire                    vta_nxt;
    wire                    vill_nxt;

    assign vlmul_nxt   = vtype_nxt[2:0];
    assign sew_nxt     = vtype_nxt[5:3];
    assign vma_nxt     = vtype_nxt[6];
    assign vta_nxt     = vtype_nxt[7];
    assign vill_nxt    = vtype_nxt[XLEN-1];
    assign vlmax_nxt   = (vlmul_nxt[2] === 1'b0) ? (VLEN_B << vlmul_nxt) >> (sew_nxt) : (VLEN_B >> (3'b100 - vlmul_nxt[1:0] + sew_nxt));

    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            sew     <= 3'h0;
            vlmul   <= 3'h0;
            vma     <= 1'b0;
            vta     <= 1'b0;
            vill    <= 1'b0;
            avl     <= VLEN_B;
            vlmax   <= VLEN_B;
        end else begin
            // only change if there is an explicit cfg instruction, obviously
            if (en) begin
                // update vtype values if using vset{i}vli
                if (cfg_type[1] === 1'b0 || cfg_type === 2'b11) begin
                    vlmul   <= vlmul_nxt;
                    sew     <= sew_nxt;
                    vma     <= vma_nxt;
                    vta     <= vta_nxt;
                    vill    <= vill_nxt;
                    vlmax   <= vlmax_nxt;
                end
                // Update AVL directly if using vsetivli
                // TODO: register version, which is more reasonable tbh (5 bits is too small for a vector lol)
                if (cfg_type === 2'b11) begin
                    avl     <= src_1;
                end else begin
                    if (~avl_set[0]) begin
                        // avl <= (avl_new <= vlmax_nxt) ? avl_new :
                                                        // ((avl_new < (vlmax_nxt << 1)) ? (avl_new >> 1 + avl_new[0]) :
                                                                                        // vlmax_nxt);
                        avl <= (avl_new < vlmax_nxt) ? avl_new : vlmax_nxt; // This is a much simpler way to do it no?
                    end else begin
                        if(avl_set === 2'b01) begin
                            avl <= vlmax_nxt;
                        end
                    end
                end
            end

            new_vl <= (en && avl_set != 2'b11);  // signals when to write back new vl
        end
    end

endmodule