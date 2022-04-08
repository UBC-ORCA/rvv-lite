module cfg_unit #(
    parameter XLEN = 32,
    parameter VLEN = 64
) (
    input                   clk,
    input                   rst_n,
    input                   en,
    input       [XLEN-1:0]  vtype_nxt,
    input       [1:0]       cfg_type,
    input       [4:0]       src_1,

    output reg  [4:0]       avl,   // Application Vector Length (vlen effective)
    output reg  [2:0]       sew,
    output reg  [2:0]       vlmul,
    output reg              vma,
    output reg              vta,
    output reg              vill
);
    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            sew     <= 3'h0;
            vlmul   <= 3'h0;
            vma     <= 1'b0;
            vta     <= 1'b0;
            vill    <= 1'b0;
            avl     <= VLEN;
        end else begin
            // only change if there is an explicit cfg instruction, obviously
            if (en) begin
                // update vtype values if using vset{i}vli
                if (cfg_type[1] === 1'b0 || cfg_type === 2'b11) begin
                    vlmul   <= vtype_nxt[2:0];
                    sew     <= vtype_nxt[5:3];
                    vma     <= vtype_nxt[6];
                    vta     <= vtype_nxt[7];
                    vill    <= vtype_nxt[XLEN-1];
                end
                // Update AVL directly if using vsetivli
                // TODO: register version, which is more reasonable tbh (5 bits is too small for a vector lol)
                if (cfg_type === 2'b11) begin
                    avl     <= src_1;
                end
            end
        end
    end

endmodule