// Asymmetric port RAM
// Write wider than Read. Write Statement in a loop.
// asym_ram_sdp_write_wider.v
module asym_ram (clkA, clkB, weA, enaA, enaB, addrA, addrB, diA, doB);
parameter WIDTHB = 8;
parameter SIZEB = 32;
parameter ADDRWIDTHB = 10;
parameter WIDTHA = 64;
parameter SIZEA = 32;
parameter ADDRWIDTHA = 10;
input clkA;
input clkB;
input weA;
input enaA, enaB;
input [ADDRWIDTHA-1:0] addrA;
input [ADDRWIDTHB-1:0] addrB;
input [WIDTHA-1:0] diA;
output [WIDTHB-1:0] doB;
`define max(a,b) {(a) > (b) ? (a) : (b)}
`define min(a,b) {(a) < (b) ? (a) : (b)}
function integer log2;
input integer value;
reg [31:0] shifted;
integer res;
begin
 if (value < 2)
 log2 = value;
 else
 begin
 shifted = value-1;
 for (res=0; shifted>0; res=res+1)
 shifted = shifted>>1;
 log2 = res;
 end
end
endfunction
localparam maxSIZE = `max(SIZEA, SIZEB);
localparam maxWIDTH = `max(WIDTHA, WIDTHB);
localparam minWIDTH = `min(WIDTHA, WIDTHB);
localparam RATIO = maxWIDTH / minWIDTH;
localparam log2RATIO = log2(RATIO);
reg [minWIDTH-1:0] RAM [0:maxSIZE-1];
reg [WIDTHB-1:0] readB;
always @(posedge clkB) begin
 if (enaB) begin
 readB <= RAM[addrB];
 end
end
assign doB = readB;
always @(posedge clkA)
begin : ramwrite
 integer i;
 reg [log2RATIO-1:0] lsbaddr;
 for (i=0; i< RATIO; i= i+ 1) begin : write1
 lsbaddr = i;
 if (enaA) begin
 if (weA)
 RAM[{addrA, lsbaddr}] <= diA[(i+1)*minWIDTH-1 -: minWIDTH];
 end
 end
end
endmodule

module bytewrite_tdp_ram_rf
 #(
//--------------------------------------------------------------------------
parameter   NUM_COL             =   8,
parameter   COL_WIDTH           =   8,
parameter   ADDR_WIDTH          =  10, 
// Addr  Width in bits : 2 *ADDR_WIDTH = RAM Depth
parameter   DATA_WIDTH      =  NUM_COL*COL_WIDTH  // Data  Width in bits
    //----------------------------------------------------------------------
  ) (
     input clkA,
     input enaA, 
     input [NUM_COL-1:0] weA,
     input [ADDR_WIDTH-1:0] addrA,
     input [DATA_WIDTH-1:0] dinA,
     output reg [DATA_WIDTH-1:0] doutA,

     input clkB,
     input enaB,
     input [NUM_COL-1:0] weB,
     input [ADDR_WIDTH-1:0] addrB,
     input [DATA_WIDTH-1:0] dinB,
     output reg [DATA_WIDTH-1:0] doutB
     );


   // Core Memory  
   reg [DATA_WIDTH-1:0]   ram_block [(2**ADDR_WIDTH)-1:0];

   integer                i;
   // Port-A Operation
   always @ (posedge clkA) begin
      if(enaA) begin
         for(i=0;i<NUM_COL;i=i+1) begin
            if(weA[i]) begin
               ram_block[addrA][i*COL_WIDTH +: COL_WIDTH] <= dinA[i*COL_WIDTH +: COL_WIDTH];
            end
         end
         doutA <= ram_block[addrA];  
      end
   end

   // Port-B Operation:
   always @ (posedge clkB) begin
      if(enaB) begin
         for(i=0;i<NUM_COL;i=i+1) begin
            if(weB[i]) begin
               ram_block[addrB][i*COL_WIDTH +: COL_WIDTH] <= dinB[i*COL_WIDTH +: COL_WIDTH];
            end
         end     
         
         doutB <= ram_block[addrB];  
      end
   end

endmodule // bytewrite_tdp_ram_rf