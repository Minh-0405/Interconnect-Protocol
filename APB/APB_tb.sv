`timescale 1ns/1ps

module APB_tb();
    logic clk, rst_n ;
    logic cmd_vld, cmd_write, cmd_mode ;
    logic [3:0] cmd_len ;
    logic ack, done ;
    logic [11:0] cmd_addr ;
    logic [31:0] cmd_wdata ;
    logic [7:0] cmd_rdata ;
    apb_if if_bus() ;

    APB_Master master(
        .clk(clk),
        .rst_n(rst_n),
        .cmd_vld(cmd_vld),
        .cmd_write(cmd_write),
        .cmd_mode(cmd_mode),
        .cmd_len(cmd_len),
        .ack(ack),
        .done(done),
        .cmd_addr(cmd_addr),
        .cmd_wdata(cmd_wdata),
        .cmd_rdata(cmd_rdata),
        .apb_m(if_bus.master)
    );

    APB_Slave slave(
        .clk(clk),
        .rst_n(rst_n),
        .apb_s(if_bus.slave)
    );

    task automatic clock(input int number) ;
        repeat(number) begin
            clk = 1'b1 ; #1 ;
            clk = 1'b0 ; #1 ;
        end
    endtask
    task automatic reset() ;
        rst_n = 1'b0 ; clock(2) ;
        rst_n = 1'b1 ;
    endtask

    initial begin
        reset() ;
        // single write test
        cmd_vld = 1 ;
        cmd_write = 1 ;
        cmd_mode = 0 ;
        cmd_addr = 12'h4 ;
        cmd_wdata = 32'hABC ;
        clock(4) ;
        cmd_vld = 0 ;
        cmd_write = 0 ;
        clock(1) ;
        // burst write test
        cmd_vld = 1 ;
        cmd_write = 1 ;
        cmd_mode = 1 ;
        cmd_len = 4'd3 ;
        cmd_addr = 12'h4 ;
        cmd_wdata = 32'hCBA ;
        clock(10) ;
        cmd_vld = 0 ;
        cmd_write = 0 ;
        clock(1) ;
        // single read test
        cmd_vld = 1 ;
        cmd_write = 0 ;
        cmd_mode = 0 ;
        cmd_addr = 12'h4 ;
        clock(4) ;
        cmd_vld = 0 ;
        clock(1) ;
        // burst read test
        cmd_vld = 1 ;
        cmd_write = 0 ;
        cmd_mode = 1 ;
        cmd_len = 4'd2 ;
        cmd_addr = 12'h8 ;
        clock(8) ;
        cmd_vld = 0 ;
        cmd_write = 0 ;
        clock(2) ;
        // end test
    end
endmodule
