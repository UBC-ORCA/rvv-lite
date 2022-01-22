module vec_regfile #(
    parameter VLEN = 128,       // bit length of a vector
    parameter ADDR_WIDTH = 5,   // this gives us 32 vectors
    parameter DATA_WIDTH = 128, // this is one vector width -- fine for access from vector accel. not fine from mem (will need aux interface)
    parameter PORTS = 2         // number of data ports
) (
    // no data reset needed, if the user picks an unused register they get garbage data and that's their problem ¯\_(ツ)_/¯
    input clk,
    input en [PORTS-1:0],           // no action unless high
    input rw [PORTS-1:0],           // 0 == read, 1 == write
    input [ADDR_WIDTH-1:0] addr [PORTS-1:0],   // 32 possible vector registers -- TODO: would like to make this SP eventually!
    input [DATA_WIDTH-1:0] data_in [PORTS-1:0],  // write 64 bits at a time
    // input [7:0] num_elems, // we can know this from vsetvli
    output reg [DATA_WIDTH-1:0] data_out [PORTS-1:0]  // read 64 bits at a time
    );

    // parameter MAX_IDX = VLEN/DATA_WIDTH - 1;
    // parameter IDX_BITS = $clog2(MAX_IDX); // screw it I can't do the math rn
    
    // reg [IDX_BITS - 1:0] curr_idx;
    reg [ADDR_WIDTH-1:0] curr_reg; // latch current register just in case input changes!
    
    wire [ADDR_WIDTH-1:0] data_start;
    wire [ADDR_WIDTH-1:0] data_end;

    // TODO: add request queue (using num_elems and busy flag) so we don't have to wait on requests to return always

    // TODO: change to a byte-addressable space, for strided reads.
    reg [DATA_WIDTH-1:0] vec_data [ADDR_WIDTH-1:0];
//   reg [DATA_WIDTH-1:0] vec_data;
//   reg [ADDR_WIDTH-1:0] vec_data [VLEN-1:0];

    reg [1:0] state;  // STATES: IDLE, BUSY_R, BUSY_W

//     assign data_start = curr_reg + curr_idx;

    // latching input values
  // always @(posedge clk) begin
  //       if (en) begin
  //           if (state[1:0] == 2'b00) begin
  //               curr_reg[ADDR_WIDTH-1:0] <= addr[ADDR_WIDTH-1:0];
  //           end
  //       end else begin
  //           curr_idx <= 0;
  //       end

  //       if (^state) begin // if state is 01 or 10 :)
  //         curr_idx <= en ? curr_idx + 1 : 0;
  //       end
  // end

    // TODO: implement multi-cycle read/write -- esp for register groupings!
//   assign data_start = curr_idx*VLEN;
//   assign data_end = data_start + VLEN - 1;

    // data read/write
  always @(posedge clk) begin
//         if (en) begin // drive enable low when we're out of bounds
            // TODO: add conditions for reading in first cycle of state change
//             if (state[1:0] == 2'b01) begin // read
    for (int i = 0; i < PORTS; i++) begin
      if (en[i] && ~rw[i]) begin
        data_out[i] <= vec_data[addr[i]];
  //                  data_tmp <= vec_data[curr_reg];
      end else if (en[i] && rw[i]) begin
  //             end else if (state[1:0] == 2'b10) begin // write
  //                 vec_data[curr_reg] <=  data_in;
        vec_data[addr[i]] <= data_in[i];
      end
    end
//         end
  end


    // STATE MACHINE :)
//       always @(posedge clk) begin
//         case (state)
//             2'b00: begin
//                 if (en) begin
//                   state <= (rw ? 2'b01 : 2'b10);
//                 end
//             end // IDLE
//             2'b01, // BUSY_RD
//             2'b10: begin
//                 state <= (curr_idx == MAX_IDX) ? 2'b00 : state;
//             end // BUSY_WR
//             default : state <= state;
//         endcase
//       end


endmodule
