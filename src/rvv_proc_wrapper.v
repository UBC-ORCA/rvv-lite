`include "rvv_proc_main.sv"

module rvv_proc_wrapper #(
    parameter VLEN              = 64,           // vector length in bits
    parameter XLEN              = 32,           // not sure, data width maybe?
    parameter NUM_VEC           = 32,           // number of available vector registers
    parameter INSN_WIDTH        = 32,           // width of a single instruction
    parameter DATA_WIDTH        = 64,
    parameter MEM_ADDR_WIDTH    = 32,           // WE ONLY HAVE MEM ADDRESSES AS REGISTER IDS RIGHT NOW
    parameter MEM_DATA_WIDTH    = 64,
    parameter VEX_DATA_WIDTH    = 32
) (
    input                               clk,
    input                               rst_n,
    input       [    INSN_WIDTH-1:0]    insn_in, // make this a queue I guess?
    input                               insn_valid,
    input       [MEM_DATA_WIDTH-1:0]    mem_port_in,
    input                               mem_port_valid_in,
    input       [VEX_DATA_WIDTH-1:0]    vexrv_data_in_1,    // memory address from load/store command?
    input       [VEX_DATA_WIDTH-1:0]    vexrv_data_in_2,
    output                              mem_port_ready_out,
    output      [MEM_DATA_WIDTH-1:0]    mem_port_out,
    output      [MEM_ADDR_WIDTH-1:0]    mem_port_addr_out,
    output                              mem_port_valid_out,
    output                              mem_port_req_out,
    output      [VEX_DATA_WIDTH-1:0]    vexrv_data_out,
    output                              proc_rdy
    // TODO: add register config outputs?
);

  rvv_proc_main #(.VLEN(VLEN), .XLEN(XLEN), .NUM_VEC(NUM_VEC), .INSN_WIDTH(INSN_WIDTH), .DATA_WIDTH(DATA_WIDTH), .MEM_ADDR_WIDTH(MEM_ADDR_WIDTH))
                rvv_proc (.clk(clk), .rst_n(rst_n), .insn_in(insn_in), .insn_valid(insn_valid), .mem_port_in(mem_port_in), .mem_port_valid_in(mem_port_valid_in),
                           .mem_port_ready_out(mem_port_ready_out), .mem_port_out(mem_port_out), .mem_port_req(mem_port_req_out), .mem_port_addr_out(mem_port_addr_out), .mem_port_valid_out(mem_port_valid_out),
                           .proc_rdy(proc_rdy), .vexrv_data_in_1(vexrv_data_in_1), .vexrv_data_in_2(vexrv_data_in_2), .vexrv_data_out(vexrv_data_out));
endmodule

// TODO: change signals back to reg/wire in proc because vivado hates them :)