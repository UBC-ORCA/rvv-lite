`include "rvv_proc_main.sv"

module rvv_proc_wrapper #(
    parameter VLEN              = 64,           // vector length in bits
    parameter XLEN              = 32,           // not sure, data width maybe?
    parameter NUM_VEC           = 32,           // number of available vector registers
    parameter INSN_WIDTH        = 32,           // width of a single instruction
    parameter DATA_WIDTH        = 64,
    parameter MEM_ADDR_WIDTH    = 5            // WE ONLY HAVE MEM ADDRESSES AS REGISTER IDS RIGHT NOW
) (
    input                               clk,
    input                               rst_n,
    input       [    INSN_WIDTH-1:0]    insn_in, // make this a queue I guess?
    input                               insn_valid,
    input       [    DATA_WIDTH-1:0]    mem_port_in,
    input                               mem_port_valid_in,
    output                              mem_port_ready_out,
    output      [    DATA_WIDTH-1:0]    mem_port_out,
    output      [MEM_ADDR_WIDTH-1:0]    mem_port_addr_out,
    output                              mem_port_valid_out,
    output                              proc_rdy
    // TODO: add register config outputs?
);

  rvv_proc_main #(.VLEN(VLEN), .XLEN(XLEN), .NUM_VEC(NUM_VEC), .INSN_WIDTH(INSN_WIDTH), .DATA_WIDTH(DATA_WIDTH), .MEM_ADDR_WIDTH(MEM_ADDR_WIDTH))
                rvv_proc (.clk(clk), .rst_n(rst_n), .insn_in(insn_in), .insn_valid(insn_valid), .mem_port_in(mem_port_in), .mem_port_valid_in(mem_port_valid_in),
                           .mem_port_ready_out(mem_port_ready_out), .mem_port_out(mem_port_out), .mem_port_addr_out(mem_port_addr_out), .mem_port_valid_out(mem_port_valid_out),
                           .proc_rdy(proc_rdy));
endmodule

// TODO: change signals back to reg/wire in proc because vivado hates them :)