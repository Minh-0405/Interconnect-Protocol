`timescale 1ns/1ps


// This file is an example use of interface in systemverilog.

interface axi_if #(
    parameter int ADDR_WIDTH = 32,
    parameter int DATA_WIDTH = 32
)(
    input logic clk, rst
);
    logic [ADDR_WIDTH:0] awaddr ;
    logic awvalid, awready ;
    logic [DATA_WIDTH:0] wdata ;
    logic wvalid, wready ;

    modport master(
        output awaddr, awvalid, wdata, wvalid,
        input awready, wready
    );

    modport slave(
        input awaddr, awvalid, wdata, wvalid,
        output awready, wready
    );
endinterface

module cpu (
    input logic clk, rst,
    axi_if.master axi_m
);
    // CPU implementation here
endmodule

module mem (
    input logic clk, rst,
    axi_if.slave axi_s
);
    // Data memory implementation here
endmodule

module interface_use (
    input logic clk,
    input logic rst_n
);

    // 1. Instantiate the physical interface (the "cable")
    axi_if #(
        .ADDR_WIDTH(32),
        .DATA_WIDTH(32)
    ) main_bus (
        .clk(clk),
        .rst_n(rst_n)
    );

    // 2. Plug the modules into the interface
    risc_v_cpu my_cpu (
        .clk(clk),
        .mem_bus(main_bus.master) // Plug into the master port
    );

    data_memory my_ram (
        .clk(clk),
        .mem_bus(main_bus.slave)  // Plug into the slave port
    );

endmodule
