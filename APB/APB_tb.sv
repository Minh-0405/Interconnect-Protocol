`timescale 1ns/1ps

module APB_tb();
    localparam int ADDR = 12 ;
    localparam int WDATA = 32 ;
    localparam int RDATA = 8 ;

    logic clk, rst_n ;
    logic cmd_vld, cmd_write, cmd_mode ;
    logic [3:0] cmd_len ;
    logic ack, done ;
    logic [ADDR-1:0] cmd_addr ;
    logic [WDATA-1:0] cmd_wdata ;
    logic [RDATA-1:0] cmd_rdata ;
    logic [WDATA/8-1:0] cmd_strb ;
    apb_if #(.ADDR_WIDTH(ADDR),
            .RDATA_WIDTH(RDATA),
            .WDATA_WIDTH(WDATA)
    ) if_bus() ;

    APB_Master #(
        .ADDR_WIDTH(ADDR),
        .WDATA_WIDTH(WDATA),
        .RDATA_WIDTH(RDATA)
    ) master (

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
        .cmd_strb(cmd_strb),
        .apb_m(if_bus.master)
    );

    APB_Slave #(
        .ADDR_WIDTH(ADDR),
        .WDATA_WIDTH(WDATA),
        .RDATA_WIDTH(RDATA)
    ) slave (
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
        cmd_addr = 12'h804 ;
        cmd_wdata = 32'hABC ;
        cmd_strb = 4'b0001 ;
        clock(9) ;
        cmd_vld = 0 ;
        cmd_write = 0 ;
        clock(1) ;
        // burst write test
        cmd_vld = 1 ;
        cmd_write = 1 ;
        cmd_mode = 1 ;
        cmd_len = 4'd1 ;
        cmd_addr = 12'h800 ;
        cmd_wdata = 32'hCBA ;
        cmd_strb = 4'b1111 ;
        clock(12) ;
        cmd_vld = 0 ;
        cmd_write = 0 ;
        clock(1) ;
        // burst read test
        slave.slow_regs[0] = 8'h44 ;
        slave.slow_regs[4] = 8'h55 ;
        slave.slow_regs[8] = 8'h66 ;
        cmd_vld = 1 ;
        cmd_write = 0 ;
        cmd_mode = 1 ;
        cmd_len = 4'd2 ;
        cmd_addr = 12'h800 ;
        clock(23) ;
        cmd_vld = 0 ;
        cmd_write = 0 ;
        clock(2) ;
        // end test
    end
endmodule
