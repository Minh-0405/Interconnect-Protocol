`timescale 1ns/1ps

interface apb_if #(
    parameter int ADDR_WIDTH = 12,
    parameter int WDATA_WIDTH = 32,
    parameter int RDATA_WIDTH = 8
)();
    logic psel ;
    logic penable ;
    logic pwrite ;
    logic [ADDR_WIDTH-1:0] paddr ;
    logic [WDATA_WIDTH-1:0] pwdata ;
    logic [RDATA_WIDTH-1:0] prdata ;
    logic pready ;

    modport master(
        output psel, penable, pwrite, paddr, pwdata,
        input prdata, pready
    );

    modport slave(
        input psel, penable, pwrite, paddr, pwdata,
        output prdata, pready
    );
endinterface

module APB_Master(
    input  logic clk, rst_n,
    input  logic cmd_vld,
    input  logic cmd_write,
    input  logic cmd_mode,
    input  logic [3:0] cmd_len,
    output logic ack,
    output logic done,
    input  logic [11:0] cmd_addr,
    input  logic [31:0] cmd_wdata,
    output logic [7:0] cmd_rdata,
    apb_if.master apb_m
);
    typedef enum logic [2:0] {
        IDLE = 3'b001,
        SETUP = 3'b010,
        ACCESS = 3'b100
    } state_t ;
    state_t state ;

    logic transfer_free ;
    logic [3:0] counter ;
    always_ff @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            state <= IDLE ;
            apb_m.psel <= 1'b0 ;
            apb_m.penable <= 1'b0 ;
            ack <= 1'b0 ;
            done <= 1'b0 ;
            transfer_free <= 1'b1 ;
        end
        else begin
            unique case(state)
                IDLE: begin
                    apb_m.psel <= 1'b0 ;
                    apb_m.penable <= 1'b0 ;
                    counter <= 'b0 ;
                    transfer_free <= 1'b1 ;
                    if(transfer_free & cmd_vld) state <= SETUP ;
                    else state <= IDLE ;
                end
                SETUP: begin
                    transfer_free <= 1'b0 ;
                    apb_m.psel <= 1'b1 ;
                    apb_m.penable <= 1'b0 ;
                    apb_m.paddr <= (cmd_addr + (counter << 2)) ;
                    apb_m.pwrite <= cmd_write ;
                    apb_m.pwdata <= cmd_wdata ;
                    counter <= counter + 1 ;
                    state <= ACCESS ;
                end
                ACCESS: begin
                    apb_m.penable <=  1'b1 ;
                    if(!cmd_mode | (cmd_mode & (!(counter ^ (cmd_len+1)))))
                        state <= IDLE ;
                    else state <= SETUP ;
                end
                default: ;
            endcase
            cmd_rdata <= (apb_m.pready & !cmd_write)? apb_m.prdata : 'bx ;
            ack <= apb_m.pready ;
            done <= (!cmd_mode & apb_m.pready) |
                             (cmd_mode & (!(counter ^ (cmd_len+1)) & apb_m.pready)) ;
        end
    end
endmodule

module APB_Slave(
    input  logic clk, rst_n,
    apb_if.slave apb_s
);
    logic [7:0] regs [4096] ;
    logic [11:0] addr_reg ;
    logic [31:0] wdata ;

    always_comb begin
        addr_reg = (apb_s.psel)? apb_s.paddr : 'bx ;
        wdata = (apb_s.psel)? apb_s.pwdata : 'bx ;
    end

    always_comb begin
        apb_s.prdata = (apb_s.penable & !apb_s.pwrite)? regs[addr_reg][7:0] : 'bx ;
        apb_s.pready = (apb_s.penable)? 1'b1 : 1'b0 ; // no wait state
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            for(int i=0 ; i<4096 ; i++) begin
                regs[i] <= 32'b0 ;
            end
        end
        else if(apb_s.penable & apb_s.pwrite) begin
            regs[addr_reg] <= wdata[7:0] ;
            regs[addr_reg+1] <= wdata[15:8] ;
            regs[addr_reg+2] <= wdata[23:16] ;
            regs[addr_reg+3] <= wdata[31:24] ;
        end
    end
endmodule
