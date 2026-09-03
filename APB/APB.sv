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
    logic [WDATA_WIDTH/8-1:0] pstrb ;
    logic [RDATA_WIDTH-1:0] prdata ;
    logic pready ;
    logic pslverr ;

    modport master(
        output psel, penable, pwrite, paddr, pwdata, pstrb,
        input prdata, pready, pslverr
    );

    modport slave(
        input psel, penable, pwrite, paddr, pwdata, pstrb,
        output prdata, pready, pslverr
    );
endinterface

module APB_Master #(
    parameter int ADDR_WIDTH = 12,
    parameter int WDATA_WIDTH = 32,
    parameter int RDATA_WIDTH = 8
)
(
    input  logic clk, rst_n,
    input  logic cmd_vld,
    input  logic cmd_write,
    input  logic cmd_mode,
    input  logic [3:0] cmd_len,
    output logic ack,
    output logic done,
    input  logic [ADDR_WIDTH-1:0] cmd_addr,
    input  logic [WDATA_WIDTH-1:0] cmd_wdata,
    input  logic [WDATA_WIDTH/8-1:0] cmd_strb,
    output logic [RDATA_WIDTH-1:0] cmd_rdata,
    apb_if.master apb_m
);
    typedef enum logic [2:0] {
        IDLE = 3'b001,
        SETUP = 3'b010,
        ACCESS = 3'b100
    } state_t ;
    state_t state, next_state ;

    logic [3:0] counter ;
    always_comb begin
        next_state = state ;
        unique case(state)
            IDLE: begin
                if(!done & cmd_vld) next_state = SETUP ;
                else next_state = state ;
            end
            SETUP: next_state = ACCESS ;
            ACCESS: begin
                if(!apb_m.pready) next_state = state ;
                else if((!cmd_mode) | (cmd_mode & (!(counter ^ (cmd_len+1)))))
                    next_state = IDLE ;
                else
                    next_state = SETUP ;
            end
            default: ;
        endcase
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            state <= IDLE ;
            apb_m.psel <= 1'b0 ;
            apb_m.penable <= 1'b0 ;
            ack <= 1'b0 ;
            done <= 1'b0 ;
        end
        else begin
            state <= next_state ;
            unique case(next_state)
                IDLE: begin
                    apb_m.psel <= 1'b0 ;
                    apb_m.penable <= 1'b0 ;
                    counter <= 'b0 ;
                    ack <= 1'b0 ;
                    done <= 1'b0 ;
                end
                SETUP: begin
                    ack <= 1'b0 ;
                    apb_m.psel <= 1'b1 ;
                    apb_m.penable <= 1'b0 ;
                    apb_m.paddr <= (cmd_addr + (counter << 2)) ;
                    apb_m.pwrite <= cmd_write ;
                    apb_m.pwdata <= cmd_wdata ;
                    apb_m.pstrb <= cmd_strb ;
                    counter <= counter + 1 ;
                end
                ACCESS: begin
                    apb_m.penable <=  1'b1 ;
                end
                default: ;
            endcase
            ack <= apb_m.pready ;
            done <= (!cmd_mode & apb_m.pready) |
                             (cmd_mode & (!(counter ^ (cmd_len+1)) & apb_m.pready)) ;
            if(apb_m.pready & !cmd_write) cmd_rdata <= apb_m.prdata ;
        end
    end
endmodule

module APB_Slave #(
    parameter int ADDR_WIDTH = 12,
    parameter int WDATA_WIDTH = 32,
    parameter int RDATA_WIDTH =8
)
(
    input  logic clk, rst_n,
    apb_if.slave apb_s
);
    logic [RDATA_WIDTH-1:0] regs [2**(ADDR_WIDTH-1)] ;
    logic [RDATA_WIDTH-1:0] slow_regs [2**(ADDR_WIDTH-1)] ;
    logic slow_regs_en [2**(ADDR_WIDTH-1)] ;

    logic [10:0] counter ;
    always_ff @(posedge clk, negedge rst_n) begin
        if(!rst_n) counter <= 'b0 ;
        else begin
            if(slow_regs_en[apb_s.paddr[ADDR_WIDTH-2:0]]) counter <= 'b0 ;
            else if(apb_s.penable & apb_s.paddr[ADDR_WIDTH-1])
                counter <= counter +1 ;
        end
    end
    genvar i ;
    generate;
        for(i=1 ; i <= 1<<(ADDR_WIDTH-1) ; i++)
        begin : g_en
            assign slow_regs_en[i-1] = (counter == i) ;
        end
    endgenerate

    always_ff @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            for(int i=0 ; i < 1<<(ADDR_WIDTH-1) ; i++) begin
                regs[i] <= 'b0 ;
                slow_regs[i] <= 'b0 ;
            end
        end
        else begin
             if(apb_s.penable & apb_s.pwrite & !apb_s.paddr[ADDR_WIDTH-1]) begin
                for(int i=0 ; i< WDATA_WIDTH/8 ; i++) begin
                    if(apb_s.pstrb[i])
                        regs[apb_s.paddr + i] <= apb_s.pwdata[i*RDATA_WIDTH +: RDATA_WIDTH] ;
                end
            end
            if(slow_regs_en[apb_s.paddr[ADDR_WIDTH-2:0]]) begin
                for(int i=0 ; i<WDATA_WIDTH/8 ; i++) begin
                    if(apb_s.pstrb[i])
                        slow_regs[apb_s.paddr[ADDR_WIDTH-2:0]+i] <= apb_s.pwdata[i*RDATA_WIDTH +: RDATA_WIDTH] ;
                end
            end
        end
    end

    always_comb begin
        apb_s.prdata = 'b0 ;
        apb_s.pready = 1'b0 ;
        apb_s.pslverr = 1'b0 ;
        if(apb_s.penable) begin
            if(!apb_s.paddr[ADDR_WIDTH-1]) begin
                apb_s.pready = 1'b1 ;
                if(!apb_s.pwrite) apb_s.prdata = regs[apb_s.paddr] ;
            end
            else begin
                if(slow_regs_en[apb_s.paddr[ADDR_WIDTH-2:0]]) begin
                    if(!apb_s.pwrite) apb_s.prdata = slow_regs[apb_s.paddr[ADDR_WIDTH-2:0]] ;
                    apb_s.pready = 1'b1 ;
                end
            end
        end
    end
endmodule
